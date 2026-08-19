#define _GNU_SOURCE

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <linux/landlock.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <unistd.h>

#define MAX_DENIED_PATHS 64
#define MAX_ALLOWED_PATHS 64

struct allowed_path {
    char path[PATH_MAX];
    bool writable;
};

static char denied_paths[MAX_DENIED_PATHS][PATH_MAX];
static size_t denied_count;
static struct allowed_path allowed_paths[MAX_ALLOWED_PATHS];
static size_t allowed_count;
static int ruleset_fd = -1;
static uint64_t handled_access;
static uint64_t read_directory_access;
static uint64_t read_file_access;
static uint64_t write_directory_access;
static uint64_t write_file_access;

static void fail_errno(const char *message, const char *path)
{
    if (path != NULL)
        fprintf(stderr, "cycle-landlock: %s: %s: %s\n", message, path,
                strerror(errno));
    else
        fprintf(stderr, "cycle-landlock: %s: %s\n", message,
                strerror(errno));
    exit(2);
}

static void fail_message(const char *message)
{
    fprintf(stderr, "cycle-landlock: %s\n", message);
    exit(2);
}

static bool same_or_beneath(const char *path, const char *root)
{
    size_t length;

    if (strcmp(root, "/") == 0)
        return path[0] == '/';
    length = strlen(root);
    return strncmp(path, root, length) == 0 &&
           (path[length] == '\0' || path[length] == '/');
}

static bool path_is_denied(const char *path)
{
    size_t index;

    for (index = 0; index < denied_count; index++) {
        if (same_or_beneath(path, denied_paths[index]))
            return true;
    }
    return false;
}

static bool path_is_denied_ancestor(const char *path)
{
    size_t index;

    for (index = 0; index < denied_count; index++) {
        if (strcmp(path, denied_paths[index]) != 0 &&
            same_or_beneath(denied_paths[index], path))
            return true;
    }
    return false;
}

static void add_rule(const char *path, bool writable)
{
    struct landlock_path_beneath_attr rule = {0};
    struct stat metadata;
    int path_fd;

    path_fd = open(path, O_PATH | O_CLOEXEC);
    if (path_fd < 0)
        fail_errno("cannot open allowed path", path);
    if (fstat(path_fd, &metadata) < 0) {
        int saved_errno = errno;
        close(path_fd);
        errno = saved_errno;
        fail_errno("cannot inspect allowed path", path);
    }
    rule.parent_fd = path_fd;
    if (S_ISDIR(metadata.st_mode))
        rule.allowed_access = writable ? write_directory_access :
                                         read_directory_access;
    else
        rule.allowed_access = writable ? write_file_access : read_file_access;
    if (syscall(SYS_landlock_add_rule, ruleset_fd,
                LANDLOCK_RULE_PATH_BENEATH, &rule, 0) < 0) {
        int saved_errno = errno;
        close(path_fd);
        errno = saved_errno;
        fail_errno("cannot add allowed path", path);
    }
    close(path_fd);
}

static void allow_children_except_denied(const char *directory,
                                         const char *allowed_root,
                                         bool writable)
{
    struct dirent *entry;
    DIR *stream;

    stream = opendir(directory);
    if (stream == NULL)
        fail_errno("cannot enumerate allowed-path frontier", directory);

    while (true) {
        char child[PATH_MAX];
        char resolved[PATH_MAX];
        struct stat link_metadata;
        int written;

        errno = 0;
        entry = readdir(stream);
        if (entry == NULL) {
            if (errno != 0) {
                int saved_errno = errno;
                closedir(stream);
                errno = saved_errno;
                fail_errno("cannot finish filesystem frontier enumeration",
                           directory);
            }
            break;
        }
        if (strcmp(entry->d_name, ".") == 0 ||
            strcmp(entry->d_name, "..") == 0)
            continue;
        if (strcmp(directory, "/") == 0)
            written = snprintf(child, sizeof(child), "/%s", entry->d_name);
        else
            written = snprintf(child, sizeof(child), "%s/%s", directory,
                               entry->d_name);
        if (written < 0 || (size_t)written >= sizeof(child)) {
            closedir(stream);
            fail_message("filesystem path exceeds PATH_MAX");
        }
        if (lstat(child, &link_metadata) < 0) {
            int saved_errno = errno;
            closedir(stream);
            errno = saved_errno;
            fail_errno("cannot inspect filesystem frontier", child);
        }
        if (realpath(child, resolved) == NULL) {
            int saved_errno = errno;
            closedir(stream);
            errno = saved_errno;
            fail_errno("cannot resolve filesystem frontier", child);
        }
        if (S_ISLNK(link_metadata.st_mode) &&
            !same_or_beneath(resolved, allowed_root))
            continue;
        if (path_is_denied(resolved))
            continue;
        if (path_is_denied_ancestor(resolved)) {
            if (S_ISLNK(link_metadata.st_mode))
                continue;
            if (!S_ISDIR(link_metadata.st_mode)) {
                closedir(stream);
                fail_message("a denied path has a non-directory ancestor");
            }
            allow_children_except_denied(resolved, allowed_root, writable);
            continue;
        }
        add_rule(resolved, writable);
    }
    closedir(stream);
}

static int landlock_abi(void)
{
    int abi;

    abi = (int)syscall(SYS_landlock_create_ruleset, NULL, 0,
                       LANDLOCK_CREATE_RULESET_VERSION);
    if (abi < 1)
        fail_errno("Landlock ABI is unavailable", NULL);
    return abi;
}

static void allow_path_except_denied(const char *path, bool writable)
{
    struct stat metadata;

    if (path_is_denied(path))
        fail_message("an allowed path intersects an explicit deny path");
    if (!path_is_denied_ancestor(path)) {
        add_rule(path, writable);
        return;
    }
    if (lstat(path, &metadata) < 0)
        fail_errno("cannot inspect allowed path", path);
    if (!S_ISDIR(metadata.st_mode))
        fail_message("a denied path has a non-directory allowed ancestor");
    allow_children_except_denied(path, path, writable);
}

static void configure_access_masks(int abi)
{
    read_directory_access =
        LANDLOCK_ACCESS_FS_EXECUTE |
        LANDLOCK_ACCESS_FS_READ_FILE |
        LANDLOCK_ACCESS_FS_READ_DIR;
    read_file_access =
        LANDLOCK_ACCESS_FS_EXECUTE |
        LANDLOCK_ACCESS_FS_READ_FILE;
    write_directory_access =
        LANDLOCK_ACCESS_FS_EXECUTE |
        LANDLOCK_ACCESS_FS_WRITE_FILE |
        LANDLOCK_ACCESS_FS_READ_FILE |
        LANDLOCK_ACCESS_FS_READ_DIR |
        LANDLOCK_ACCESS_FS_REMOVE_DIR |
        LANDLOCK_ACCESS_FS_REMOVE_FILE |
        LANDLOCK_ACCESS_FS_MAKE_CHAR |
        LANDLOCK_ACCESS_FS_MAKE_DIR |
        LANDLOCK_ACCESS_FS_MAKE_REG |
        LANDLOCK_ACCESS_FS_MAKE_SOCK |
        LANDLOCK_ACCESS_FS_MAKE_FIFO |
        LANDLOCK_ACCESS_FS_MAKE_BLOCK |
        LANDLOCK_ACCESS_FS_MAKE_SYM;
    write_file_access =
        LANDLOCK_ACCESS_FS_EXECUTE |
        LANDLOCK_ACCESS_FS_WRITE_FILE |
        LANDLOCK_ACCESS_FS_READ_FILE;
    if (abi >= 2)
        write_directory_access |= LANDLOCK_ACCESS_FS_REFER;
    if (abi >= 3) {
        write_directory_access |= LANDLOCK_ACCESS_FS_TRUNCATE;
        write_file_access |= LANDLOCK_ACCESS_FS_TRUNCATE;
    }
    handled_access = write_directory_access;
}

static void create_ruleset(void)
{
    struct landlock_ruleset_attr ruleset = {0};

    ruleset.handled_access_fs = handled_access;
    ruleset_fd = (int)syscall(SYS_landlock_create_ruleset, &ruleset,
                              sizeof(ruleset), 0);
    if (ruleset_fd < 0)
        fail_errno("cannot create Landlock ruleset", NULL);
}

static void enforce_ruleset(void)
{
    if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) < 0)
        fail_errno("cannot enable no_new_privs", NULL);
    if (syscall(SYS_landlock_restrict_self, ruleset_fd, 0) < 0)
        fail_errno("cannot enforce Landlock ruleset", NULL);
    close(ruleset_fd);
    ruleset_fd = -1;
}

int main(int argc, char **argv)
{
    int command_index = -1;
    int abi;
    int index;

    for (index = 1; index < argc; index++) {
        if (strcmp(argv[index], "--") == 0) {
            command_index = index + 1;
            break;
        }
        if (index + 1 >= argc)
            fail_message("usage: cycle-landlock (--read|--write|--deny) <path> [...] -- <command> [args]");
        if (strcmp(argv[index], "--deny") == 0) {
            if (denied_count >= MAX_DENIED_PATHS)
                fail_message("too many denied paths");
            index++;
            if (realpath(argv[index], denied_paths[denied_count]) == NULL)
                fail_errno("cannot resolve denied path", argv[index]);
            if (strcmp(denied_paths[denied_count], "/") == 0)
                fail_message("refusing to deny the filesystem root");
            denied_count++;
            continue;
        }
        if (strcmp(argv[index], "--read") == 0 ||
            strcmp(argv[index], "--write") == 0) {
            bool writable = strcmp(argv[index], "--write") == 0;

            if (allowed_count >= MAX_ALLOWED_PATHS)
                fail_message("too many allowed paths");
            index++;
            if (realpath(argv[index], allowed_paths[allowed_count].path) == NULL)
                fail_errno("cannot resolve allowed path", argv[index]);
            allowed_paths[allowed_count].writable = writable;
            allowed_count++;
            continue;
        }
        fail_message("usage: cycle-landlock (--read|--write|--deny) <path> [...] -- <command> [args]");
    }
    if (allowed_count == 0 || command_index < 0 || command_index >= argc)
        fail_message("usage: cycle-landlock (--read|--write|--deny) <path> [...] -- <command> [args]");

    abi = landlock_abi();
    configure_access_masks(abi);
    create_ruleset();
    for (index = 0; (size_t)index < allowed_count; index++)
        allow_path_except_denied(allowed_paths[index].path,
                                 allowed_paths[index].writable);
    enforce_ruleset();
    execvp(argv[command_index], &argv[command_index]);
    fail_errno("cannot execute sandboxed runtime", argv[command_index]);
    return 2;
}
