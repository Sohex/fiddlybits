# git holds one ssh session open for the whole pre-push hook, and GitHub closes an idle session at six minutes, so a nine-minute gate makes every push die on SIGPIPE with nothing printed

Measured on 2026-09-12 on yggdrasil. git 2.55.0, OpenSSH as configured for this host,
Fiddlybits at `c466a70` on `main`. The remote is `git@github.com:Sohex/fiddlybits.git`
over ssh. Every number below is a direct observation; nothing here is inferred from
documentation. The row is `fiddlybits-52v.1.12`.

## What was seen first

Three pushes of `main` were attempted, two by an agent and one by the user in their own
terminal. Each ran the `pre-push` hook, which runs `tools/gate/gate.sh`, which runs the
whole suite through the scheduler. Each time the suite passed, 4866 assertions, at
9m07.0s and 9m27.6s on the two runs that were logged. Each time `git push` then exited
**141** having transferred nothing, printed no error, and left `origin/main` where it
was. 141 is 128 + 13, which is SIGPIPE.

Ruled out first, each by its own measurement: the scheduler does not close a child's
inherited stdin (a writer to a `qrun` child's stdin survives both an immediate and a
delayed write); output volume is not it (300000 lines through the gate's own profile
and flags, exit 0); a short job through the gate's exact flags is fine (exit 0, with and
without a pipe on stdin).

## git holds a connection open for the length of the hook

`git push` learns each remote SHA before it runs `pre-push`, which is how the hook's
stdin lines carry one. The question was whether it keeps that connection open while the
hook runs, or reconnects afterwards.

Observed directly, with a 90-second stand-in hook via `git -c core.hooksPath=... push
--dry-run`, and with no other ssh session on the host:

    :22 connections before git runs        0
    during the hook                        1  ESTAB ... 140.82.114.3:22  users:(("ssh",pid=2414505,fd=3))
    children of git (pid 2414503)          ssh 2414505, sh 2414506

One established session to GitHub, owned by an `ssh` whose parent is the `git` process,
alongside the `sh` that is the hook itself. git holds the socket for the hook's whole
duration.

## GitHub closes an idle session at six minutes

Sessions were opened with `ssh git@github.com git-upload-pack`, left idle, then written
to. Three runs, each opening its marks' sessions together and probing one per mark. The
marks are measured from about five seconds after the connections opened, so true idle
time is about five seconds more than each mark.

| idle mark | run A | run B | run C |
|---|---|---|---|
| 120 s | alive | - | - |
| 240 s | alive | - | - |
| 250 s | - | alive | - |
| 280 s | - | alive | - |
| 300 s | - | alive | - |
| 320 s | - | alive | - |
| 350 s | - | alive | - |
| 360 s | closed | - | closed |
| 420 s | - | - | closed |
| 480 s | closed | - | closed |
| 540 s | - | - | closed |
| 600 s | closed | - | closed |

Alive at 350, closed at 360, in every run that tested those marks. The threshold is
therefore about 360 seconds of idle, six minutes. A closed session reports
`Connection to github.com closed by remote host.`, `ssh` exits 255, and a write to it
raises a broken pipe.

Nothing on this host keeps the session warm. `ssh -G git@github.com` reports
`serveraliveinterval 0`, so there are no application-level keepalives, and while
`tcpkeepalive yes` is set, the Linux default does not send the first probe until the
connection has been idle for two hours.

## The arithmetic, and why nothing is printed

The gate is 9m07.0s to 9m27.6s. The window is 6m00s. The gate has exceeded the window by
about half again for as long as it has been this slow, which is why all three pushes
failed rather than some of them. When the hook returns, git writes the pack to a socket
the far end closed minutes earlier, takes SIGPIPE, and dies before it can report
anything. The silence is the signature: a hook that refused would have printed the gate's
own refusal, and a network error reached through git's own error path would have printed
that.

## What this fixes, and what was not changed

Masking it is one option: `git -c core.sshCommand='ssh -o ServerAliveInterval=30' push`
keeps the session warm across the hook. That was not taken as a repository setting,
because a hook holding a remote connection open for the length of a full test run is the
defect, and a keepalive hides it rather than removing it.

Moving the whole-suite backstop was put to the user as two alternatives and both were
declined on 2026-09-12: running it from `pre-commit` makes every commit that stages
source pay the full wall time and inverts the economics `docs/workflow.md` is written
around, and deleting the `pre-push` block leaves no hook-level backstop at all. The hooks
are therefore unchanged, and pushes go out by hand with `git push --no-verify` until
`fiddlybits-52v.1.12` resolves. Only `pre-push` is skipped that way: the `pre-commit`
lints and reference-hash check and the `commit-msg` `answers:` rule fire at commit and
are untouched.

## The number this sets for fiddlybits-52v.1.12

A pre-push gate is viable only while the suite finishes inside six minutes, with margin
for the pack transfer and for a threshold this record measured on one day against one
remote. The suite is 4866 assertions in about nine and a half minutes and runs on one
core of the eight `.taskrunner.toml` asks for. That is the target: not "faster", but
inside the window, and reached by restructuring rather than by testing less.
