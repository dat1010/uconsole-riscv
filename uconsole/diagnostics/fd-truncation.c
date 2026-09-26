#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

int main(void) {
    int channel[2], peers[8], passed[8];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, channel)) return 2;
    for (int i = 0; i < 8; ++i) {
        int pair[2];
        if (socketpair(AF_UNIX, SOCK_STREAM, 0, pair)) return 2;
        peers[i] = pair[0];
        passed[i] = pair[1];
    }
    char byte = 1;
    struct iovec iov = { &byte, 1 };
    union { struct cmsghdr align; char bytes[CMSG_SPACE(sizeof(passed))]; } outgoing = {0};
    struct msghdr message = {0};
    message.msg_iov = &iov;
    message.msg_iovlen = 1;
    message.msg_control = outgoing.bytes;
    message.msg_controllen = sizeof(outgoing.bytes);
    struct cmsghdr *control = CMSG_FIRSTHDR(&message);
    control->cmsg_level = SOL_SOCKET;
    control->cmsg_type = SCM_RIGHTS;
    control->cmsg_len = CMSG_LEN(sizeof(passed));
    memcpy(CMSG_DATA(control), passed, sizeof(passed));
    if (sendmsg(channel[0], &message, 0) != 1) return 2;
    for (int i = 0; i < 8; ++i) close(passed[i]);

    union { struct cmsghdr align; char bytes[CMSG_SPACE(sizeof(int))]; } incoming = {0};
    message.msg_control = incoming.bytes;
    message.msg_controllen = sizeof(incoming.bytes);
    if (recvmsg(channel[1], &message, MSG_CMSG_CLOEXEC) != 1) return 2;
    int received = 0;
    for (control = CMSG_FIRSTHDR(&message); control; control = CMSG_NXTHDR(&message, control)) {
        if (control->cmsg_level != SOL_SOCKET || control->cmsg_type != SCM_RIGHTS) continue;
        int count = (control->cmsg_len - CMSG_LEN(0)) / sizeof(int);
        int *fds = (int *)CMSG_DATA(control);
        for (int i = 0; i < count; ++i) { close(fds[i]); ++received; }
    }
    int open_peers = 0;
    for (int i = 0; i < 8; ++i) {
        if (recv(peers[i], &byte, 1, MSG_DONTWAIT) != 0) ++open_peers;
        close(peers[i]);
    }
    close(channel[0]);
    close(channel[1]);
    printf("received=%d truncated=%d peers_still_open=%d\n", received,
           !!(message.msg_flags & MSG_CTRUNC), open_peers);
    return open_peers != 0;
}
