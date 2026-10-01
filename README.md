<p align="center">
  <a href="https://github.com/AntilaX-3/"><img src="https://avatars.githubusercontent.com/u/35715409" width="150" title="AntilaX-3"></a>
</p>

<p align="center">
  <a href="https://buildkite.com/antilax-3/alpine"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/dynamic/json.svg?url=https%3A%2F%2Fimg.shields.io%2Fbuildkite%2F8305d1c231870d9562e8ab799b849789f26467aaa667a262b7%2Fmaster.json&query=%24.message&label=build&logo=buildkite&logoColor=%2314cc80&mode=dark&size=sm&variant=outline"><img alt="Build" src="https://shieldcn.dev/badge/dynamic/json.svg?url=https%3A%2F%2Fimg.shields.io%2Fbuildkite%2F8305d1c231870d9562e8ab799b849789f26467aaa667a262b7%2Fmaster.json&query=%24.message&label=build&logo=buildkite&logoColor=%2314cc80&mode=light&size=sm&variant=outline"></picture></a>
  <a href="https://hub.docker.com/r/antilax3/alpine/tags"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/dynamic/json.svg?url=https%3A%2F%2Fimg.shields.io%2Fdocker%2Fimage-size%2Fantilax3%2Falpine%2Flatest.json&query=%24.message&label=image%20size&logo=docker&logoColor=%232496ed&mode=dark&size=sm&variant=outline"><img alt="Docker Size" src="https://shieldcn.dev/badge/dynamic/json.svg?url=https%3A%2F%2Fimg.shields.io%2Fdocker%2Fimage-size%2Fantilax3%2Falpine%2Flatest.json&query=%24.message&label=image%20size&logo=docker&logoColor=%232496ed&mode=light&size=sm&variant=outline"></picture></a>
  <a href="https://hub.docker.com/r/antilax3/alpine"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/dynamic/json.svg?url=https%3A%2F%2Fimg.shields.io%2Fdocker%2Fpulls%2Fantilax3%2Falpine.json&query=%24.message&label=pulls&logo=docker&logoColor=%232496ed&mode=dark&size=sm&variant=outline"><img alt="Docker Pulls" src="https://shieldcn.dev/badge/dynamic/json.svg?url=https%3A%2F%2Fimg.shields.io%2Fdocker%2Fpulls%2Fantilax3%2Falpine.json&query=%24.message&label=pulls&logo=docker&logoColor=%232496ed&mode=light&size=sm&variant=outline"></picture></a>
</p>

# AntilaX-3/alpine

### This base container is not aimed at public consumption. It exists to serve as a single endpoint for AntilaX-3 containers and is based upon [Alpine Linux](https://hub.docker.com/_/alpine/) and [S6 overlay](https://github.com/just-containers/s6-overlay) forked from [linuxserver.io](https://github.com/linuxserver/docker-baseimage-alpine).

## Development

Linting runs locally through [lefthook](https://github.com/evilmartians/lefthook). Install the hooks once per clone:

```bash
lefthook install
```

`pre-commit` runs [editorconfig-checker](https://github.com/editorconfig-checker/editorconfig-checker),
[hadolint](https://github.com/hadolint/hadolint), `jq`, [shellcheck](https://github.com/koalaman/shellcheck),
[typos](https://github.com/crate-ci/typos) and [yamllint](https://github.com/adrienverge/yamllint) over the staged
files, and `commit-msg` enforces [Conventional Commits](https://www.conventionalcommits.org). Run everything on demand
with:

```bash
lefthook run pre-commit --all-files
```

