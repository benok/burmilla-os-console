# unofficial Burmilla OS console images
Docker console Images for BurmillaOS (work in progress)
(forked from racher/os-services:v1.5.8)

## Building

Run `make`

## Details

### Multi-arch Dockerfiles

As a pre-cursor to native multi-arch support, we leverage some features of
[dapper](https://github.com/rancher/dapper).

In the Dockerfiles, you'll see lines like:

```
FROM rancher/os-centosconsole-base
# FROM amd64=centos:7 arm64=skip arm=skip
```

The `rancher/os-centosconsole-base` does not actually exist. Dapper will download the
arch specific image listed in the commented out `# FROM` line, and tag that, so the
build can occur.

## Special Entrypoint and CMD

Console images also use special ENTRYPOINT and CMD settings, which are bind mounted
into the container at run time:

```
ENTRYPOINT ["/usr/bin/ros", "entrypoint"]
```

## Misc details

The sshd is configured to accept logins from users in the `docker` group, and `root` is denied.
