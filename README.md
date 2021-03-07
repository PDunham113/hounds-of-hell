# Installing Vagrant
You will need
-   Vagrant [(HashiCorp)][vagrant install]
-   VirtualBox [(Oracle)][virtualbox install]
-   A working Git installation & SSH client ([Cygwin][] or [Git for Windows][]
    work well on Windows, otherwise consult your OS package manager)

The Vagrantfile is split into 3 parts:
-   `Vagrantfile`: Deals with general VM configuration. (Mostly) project
    independent, should rarely require editing.
-   `Vagrantfile.project`: Deals with installing project-level tools and
    dependencies. This should not include user-specific settings.
-   `Vagrantfile.local`: Deals with user preferences and machine-specific
    settings. As this is intended to be user-specific, Git will ignore this
    file. A template (`Vagrantfile.local.example`) is included, and will be
    copied to `Vagrantfile.local` the first time you run `vagrant up`.

To boot the VM, navigate to the Vagrant folder (`<project>/Vagrant`) and run the
following commands from a terminal/command prompt:
```
vagrant up
vagrant ssh
```
That's it! The first `vagrant up` will likely take a few minutes while all
prerequisites are installed. Any `vagrant up` calls from a halt or suspend will
take significantly less time.

To power down, suspend, or kill the VM, run any of the following:
-   `vagrant suspend`: Pause VM, free resources. Fast startup, needs extra disk
    space.
-   `vagrant halt`: Shut VM down. Slow-ish startup, minimal disk space.
-   `vagrant destroy`: Wipe all traces of VM from system.

The VM is configured to automatically capture any FTDI serial cables or Pololu
USB AVR programmers attached to the computer, allowing them to be available
from within the VM. As a consequence, they will not be available to the host
computer. These resources will be freed once the VM is halted or suspended.

##### SSH Keys
If you use SSH keys to log in to GitHub, edit your `Vagrantfile.local` to load
them by modifying `$ssh_key_location` and `$ssh_public_key`. If your VM is
already running, typing `vagrant provision` will re-provision the machine
in-place. You will need to start the SSH agent and add your key for Vagrant to
recognize it by running the following commands:
```
eval `ssh-agent -s`
ssh-add <ssh_private_key_location>
```

##### Common issues
-   **Vagrant commands won't work:**
    -   Ensure virtualization extensions are enabled (you may need to check
        your BIOS).
-   **git fetch/push/pull/etc. keep asking for credentials:**
    -   Either use a credential helper within the Vagrant machine or connect to
        Github with SSH.
-   **git status on (Vagrant/Cygwin/Windows) shows all files as modified, but
    nothing has changed:**
    -   The easiest solution to this is to remove the Git for Windows line
        ending filter from your `.gitconfig` file and configure your text
        editor to use `\n` for line endings.

[Main README][]

[Main README]: ../README.md

[Cygwin]: https://cygwin.com/install.html
[Git for windows]: https://git-scm.com/download/win
[Vagrant install]: https://www.vagrantup.com/downloads.html
[Virtualbox install]: https://www.virtualbox.org/wiki/Downloads
