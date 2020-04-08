---
lets_encrypt: https://letsencrypt.org
cloudflare: https://cloudflare.com
acme.sh: https://github.com/acmesh-official/acme.sh

---

## Acme script for automating installation of [Let's Encrypt]( https://letsencrypt.org) certificates via a [Cloudflare]( https://cloudflare.com ) DNS challenge with creating of systemd service and timer files for Automated Renewal of SSL Certificates

### Purpose

This script is an attempt to automate the installation process of [Let's Encrypt](https://letsencrypt.org/) certificates via a [Cloudflare](https://cloudflare.com)   

Use of this script requires
  - [acme.sh](https://github.com/acmesh-official/acme.sh) has been installed on clinet
  - A Linux distribution with [systemd](https://en.wikipedia.org/wiki/Systemd) system and service manager.  This script is untested on BSD-type systems.
  - [Cloudflare](https://cloudflare.com) account with Cloudflare managing DNS records for domain.  User should be familiar with altering/changing DNS record.

 ### [Cloudflare](https://cloudflare.com) requirements

In order to issue/renew [Let's Encrypt](https://letsencrypt.org/) you'll need one pair of data:
   
  - Cloudflare Global API key / Email Address Registered with Cloudflare OR
  - Cloudflare API Token / Cloudflare Account-ID

Information how to obtain this data can be found on the Cloudflare Website

### Acme.sh

[acme.sh](https://github.com/acmesh-official/acme.sh) was chosen as the mechanism to obtain and renew SSL certificates.  [Certbot](https://certbot.rog) could be used as an alternative however I felt acme.sh was more customizable.

### Systemd

Because all my working linux systems utilize systemd as the service/timer manager, I wanted to incorporate systemd.timers rathers than cron jobs in order to automate renewal of the certs. This script will create and activate the necessary service and timer files to allow for automated renewal.

## Usage

Usage instructions are shown via:

```bash
$ ./acme-install-new-cert.sh --help
```

Since my installation of certificates is done very uncommonly, I typically need to progress through stages to ensure things will be done correctly prior to generating/installing the certificate and creating the systemd service/timer files

The script can be ran with the `--dry-run` option which will simply echo back the command line arguments in order to verify syntax is correct since there is no syntax checking within the script

The flags `-t/--test` and `--do-not-install` are often used together when wanting to do a "trial run" to ensure Let's Encrypt Servers are working.  I would encourage use of these parameters in nearly every case

The `--force` command is needed after using the `--test` command above.  Unlike certbot.sh, when acme.sh uses Let's Encrypt test servers, it will actually download and temporarily hold the "bogus test certificate".  The force command is to tell acme.sh to forget this "bogus certificate" and actually install the certificate from Let's Encrypt's production servers. (Certbot for the record does not need this workaround).

The `-c/--command` option is the command that is run after installation of the certificate.  Common examples for this could be "nginx -s reload" or other such variant.  This command is optional.  If you need to change the reload command in the future, run this script with the --do-not-issue flag.  The reload command will be changed without forcing Let's Encrypt to issue a new certificate

Systemd timers can be checked:

```bash
systemctl list-timers
```
