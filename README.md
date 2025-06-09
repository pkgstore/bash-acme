# ACME

## Install

```bash
export SET_DIR='/root/apps/acme'; export GH_NAME='bash-acme'; export GH_URL="https://github.com/pkgstore/${GH_NAME}/archive/refs/heads/main.tar.gz"; curl -Lo "${GH_NAME}-main.tar.gz" "${GH_URL}" && tar -xzf "${GH_NAME}-main.tar.gz" && { cd "${GH_NAME}-main" || exit; } && { for i in app_*; do install -m '0644' -Dt "${SET_DIR}" "${i}"; done; } && { for i in cron_*; do install -m '0644' -Dt '/etc/cron.d' "${i}"; done; } && chmod +x "${SET_DIR}"/*.sh
```

## Resources

- [Documentation (RU)](https://lib.onl/ru/2025/03/481a0666-eb21-555f-858f-0c2d695b9a74/)
