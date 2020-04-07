---
lets_encrypt: https://letsencrypt.org
cloudflare: https://cloudflare.com
acme.sh: https://github.com/acmesh-official/acme.sh

---

## Acme script for automating installation of [Let's Encrypt]({{ page.lets_encrypt }}) certificates via a [Cloudflare]({{ page.cloudflare }}) DNS challenge with creating of systemd service and timer files for Automated Renewal of SSL Certificates

### Purpose

This script is an attempt to automate the installation process of [Let's Encrypt](https://letsencrypt.org/) certificates via a [Cloudflare](https://cloudflare.com)   

Use of this script requires
  - [acme.sh](https://github.com/acmesh-official/acme.sh) has been installed on clinet
  - A Linux distribution with [systemd](https://en.wikipedia.org/wiki/Systemd) system and service manager.  This script is untested on BSD-type systems.
  - [Cloudflare](https://cloudflare.com) account with Cloudflare managing DNS records for domain.  User should be familiar with altering/changing DNS record.

 #### [Cloudflare](https://cloudflare.com) requirements

 In order to issue/renew [Let's Encrypt](https://letsencrypt.org/)
