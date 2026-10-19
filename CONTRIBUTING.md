# Contributing

The useful reports are the cases where the banner was wrong: a reboot it missed, one it reported twice, or a pending attempt matched to the wrong boot. Open an issue with the macOS version, your config (without passwords), the banner lines and the files in the state folder (`pending.json`, `boottime.txt`, the newest `last-*.json`). Apps that still came back after the restart are worth a report too, with the macOS build.

Pull requests: keep them small and say how you tested them. Anything that restarts the machine is tested on a real restart before I merge it. AI-assisted PRs are fine as long as you can explain the change, which is the same bar I hold my own code to.
