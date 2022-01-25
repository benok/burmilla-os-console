# unofficial BurmillaOS console images
Docker console Images for BurmillaOS. (work in progress)

(forked from racher/os-services:v1.5.8)

## Background

[BurmillaOS](https://burmillaos.org/) chooses debian console as the default console & [doesn't support any other consoles](https://github.com/burmilla/os-services/commit/be9ad101725d7d56adc6849990ba4a99fa26c4de) like Alpine, Ubuntu, CentOS that can be used on RancherOS.

But, Burmilla's Debian based default console is [based on **slim** container](https://github.com/burmilla/os/blob/v1.9.x/images/02-console/Dockerfile). 

I think, slim container is intended to be used as a base of application container, and not to be used as an interactive console. (For example, man page installation is blocked within slim container.)

## How to Use

Add following settings to your cloud-init.yml to refer console image from this repository.

(You can use [ros config](https://burmillaos.org/docs/configuration/), or directly edit /var/lib/rancher/conf/cloud-config.d/user_config.yml with sudo.)

```yml
rancher:
  repositories:
     console:
      url: https://raw.githubusercontent.com/benok/burmilla-os-console/master
```

With above setting, you can find other consoles as like RancherOS.
```sh
rancher@burmilla:~$ sudo ros console list
disabled alpine
disabled centos
disabled debian
enabled default
disabled fedora
disabled ubuntu
rancher@burmilla:~$
```

Now, choose your favorite console.
```sh
rancher@burmilla:~$ sudo ros console enable debian
Pulling console (docker.io/benok/os-debianconsole:latest)...
latest: Pulling from benok/os-debianconsole
9b99af5931b3: Pull complete
31abf1b3ffe9: Pull complete
71b31c084f4a: Pull complete
f89c9533bcc8: Pull complete
a422cc09bdf6: Pull complete
Digest: sha256:5f8ec5e744b082aff176774827aac3385205dc15468a12f36f83214a97de75d6
Status: Downloaded newer image for benok/os-debianconsole:latest
```

After reboot, your console now switched to the one you choose.
```sh
rancher@burmilla:~$ sudo reboot
```

See also
* [How to switch console](https://burmillaos.org/docs/installation/custom-builds/custom-console/)
* [Creating your own console](https://burmillaos.org/docs/system-services/custom-system-services/#creating-your-own-console)

### Note:
Please use **'ros console enable'** and reboot.

**'ros console switch' doesn't work correctly from [RancherOS era](https://github.com/rancher/os/issues?q=is%3Aissue+is%3Aopen+%22ros+console+switch%22).**

## Warning

Currently, **only debian console is tested**.

Any other console is same image as RancherOS v1.5.8.

(I'm a debian user. I might update other consoles, but pull requests are welcome.)

## Notes on Debian console
* based on non-slim image
* uses buster as Burmilla's default console uses
* Followed [most of upstream changes](https://github.com/benok/burmilla-os-console/commit/aa5b21ec7a150ca35cf57ec576e765a2d6a08530)
* ssh configuration is not changed from RancherOS's now. (I want to update this to recent Debian's default.)
* If you want to generate /etc/lsb-release as the default console, add "/etc/init.d/generate-lsb-release start" to runcmd.
```yml
runcmd:
  - (your 
  -  settings
  -  ...)
  - /etc/init.d/generate-lsb-release start
```

### See also (my tickets)
* [Making console container customizable #126](https://github.com/burmilla/os/issues/126)
* [Change of default sshd.config is not good #102](https://github.com/burmilla/os/issues/102)

---
## How to build your own console and use

1. Clone this repository.
2. Change [OS_REPO](https://github.com/benok/burmilla-os-console/commit/ce9e7f073012195d1b9fba1bef2e758050a9f97f) and [yaml's docker registry config](https://github.com/benok/burmilla-os-console/commit/dffea9b5f9717b845560e8366e3fc61dd99f29e0) to your Docker Hub account.
3. make
4. Change images/10-*console/Dockerfile
5. Push all your images to dockerhub.
```sh
$ docker image push [your-account]/os-xxxxconsole -a
```
6. Push changes to github and follow "How to Use".(changing url is required, of cource.)

---
## Original Build Instructions (from [rancher/os-services](https://github.com/rancher/os-services#readme))

### Building

Run `make`

### Details

#### Multi-arch Dockerfiles

As a pre-cursor to native multi-arch support, we leverage some features of
[dapper](https://github.com/rancher/dapper).

In the Dockerfiles, you'll see lines like:

```docker
FROM rancher/os-centosconsole-base
# FROM amd64=centos:7 arm64=skip arm=skip
```

The `rancher/os-centosconsole-base` does not actually exist. Dapper will download the
arch specific image listed in the commented out `# FROM` line, and tag that, so the
build can occur.

### Special Entrypoint and CMD

Console images also use special ENTRYPOINT and CMD settings, which are bind mounted
into the container at run time:

```docker
ENTRYPOINT ["/usr/bin/ros", "entrypoint"]
```

### Misc details

The sshd is configured to accept logins from users in the `docker` group, and `root` is denied.
