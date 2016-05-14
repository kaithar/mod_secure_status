# mod_secure_status
## Description
This is a drop in replacement for Apache HTTPd's mod_status.

The primary feature of is the addition of `SecStatus_PermitIPs` which enforces
server wide IP whitelist access control for the module.  This prevents rogue
use of `SetHandler server-status` in .htaccess files, particularly useful on
shared hosting servers.

## FAQ
### 1. Why didn't you submit this upstream instead?
Because I'm lazy and not familiar with Apache's API, thus this code is mostly
a Frankenstein graft of code from mod_rpaf in to mod_status.
Since I didn't write the code I've lifted from rpaf, and can't clean room an
implementation myself in the time I have available for it, I'm not comfortable
submitting this upstream to ASF.  Even if I were, I can't submit a CLA for the
code from rpaf and thus wouldn't have it accepted.

So, since I can't submit it upstream but both bits of code are under compatible
licences, I'm releasing it directly.  Think of it as the next best option.

## Installation and Use
### Step 0: Short cut method
If you're installing from source, or have a package manager that can compile for
you, you can skip the compiling steps by using the supplied patch instead.

#### Gentoo patch injection.
Portage will apply custom patches during install.  Try the following:

```bash
mkdir -p /etc/portage/patches/www-servers/apache/
wget https://raw.githubusercontent.com/kaithar/mod_secure_status/master/mod_secure_status.patch \
    -O /etc/portage/patches/www-servers/apache/mod_secure_status.patch
```

You will also need to put this in to `/etc/portage/bashrc` if you haven't used
/etc/portage/patches before.
```bash
pre_src_prepare() {
    if ! type epatch_user > /dev/null 2>&1; then
        local names="epatch_user epatch evar_push evar_push_set evar_pop estack_push estack_pop"
        source <(awk "/^# @FUNCTION: / { p = 0 } /^# @FUNCTION: (${names// /|})\$/ { p = 1; } p { print  }" /usr/portage/eclass/eutils.eclass)
    fi

    epatch_user

    for name in $names; do
        unset $name
    done
}
```
See [this](http://wiki.gentoo.org/wiki//etc/portage/patches) page for full details.

If `emerge -va apache` succeeds you can skip straight to Step 4 for usage

### Step 1: Dependencies
Note: If you have the option to do so, I'd advise first setting your package
manager nuke or just not install the status module, to be on the safe side.

- On Gentoo: Remove `status` from your `APACHE2_MODULES` variable.

#### Debian
If you're compiling on a Debian variant (such as Ubuntu) you'll need this:
`sudo apt-get install build-essential apache2-dev`

#### RedHat
If you're compiling on a RedHat variant (such as CentOS, Fedora, RHEL) you need:
`sudo yum install httpd-devel`

#### Gentoo
If you're on Gentoo `emerge -va apache` should give you everything you need.

#### Other
If you're on something else you're on your own, but feel free to open an issue
with the required package manager instruction and I can add them.

### Step 2: Compile
`make all`

Wasn't that easy?

### Step 3: Installing

This code is intended to replace the stock mod_status.so file, however that does
have some disadvantages.  Primarily, the stock mod_status will be restored when
apache is updated/reinstalled, not what we want at all.

Thus you have two options:

- If you want to overwrite the stock mod_status, use this:
  `sudo make clobber`
  > You'll need to remember to reinstall it every time though.

- If you want to install it as it's own module, use this:
  `sudo make install`
  > This has the advantage of not being overwritten by the stock mod_status,
  but does mean that you'll have to do a little extra work to enable it.

### Step 4: Enabling and Usage

If you opted to clobber mod_status it may already be enabled.
If you need to, you can enable it as normal like:
```apache
LoadModule status_module modules/mod_status.so
```

If you've installed it as it's own module you'll need to make sure the line
looking like the previous one is disabled and instead add this:
```apache
LoadModule status_module modules/mod_secure_status.so
```

Note that the `status_module` part of that isn't a typo.

Once loaded, the config is mostly familiar:
```apache
SecStatus_PermitIPs 127.0.0.1 10.0.0.0/24
<Location /server-status>
        SetHandler server-status
</Location>
```

The primary difference is the `SecStatus_PermitIPs` directive.  It is similar to
having an `Order` directive such as
```apache
Order Allow,Deny
Allow from 127.0.0.1
```
Unlike the `Order` directive, however, the `SecStatus_PermitIPs` directive is
applied globally and cannot be overridden, making it safer when third parties
can upload .htaccess files to your server.

The `SecStatus_PermitIPs` directive is only valid in the server config context.
Thus it must be specified at the root level in the server config and cannot be
in a `<VirtualHost>`, `<Location>` or `<Directory>` container.  It is also not
valid in a .htaccess file.
Attempting to specify it in the wrong place will result in a syntax error:
> SecStatus_PermitIPs not allowed here

This module defaults to allowing no IPs access, thus returning a 403 response
for every request when `SecStatus_PermitIPs` isn't set.  This is an intentional
fail-safe decision.
If `SecStatus_PermitIPs` is set and the config manages to load vanilla
`mod_status` instead of this version, Apache will throw a syntax error:
> Invalid command 'SecStatus_PermitIPs', perhaps misspelled or defined by a module not included in the server configuration

This can act as a fail safe, preventing the unsecured version from loading.

The module name is provided as `status_module`, the same as the vanilla module,
in order to force a conflict should both versions be loaded:
```apache
LoadModule status_module modules/mod_status.so
LoadModule status_module modules/mod_secure_status.so
```
Causes:
> [warn] module status_module is already loaded, skipping.

If the wrong version is loaded, the previously mentioned behaviours kick in.
If the correct version is loaded, the server will start and behave as expected.
This is intended to protect against the situation of having both available, as
might be possible if both modules were loaded.

Attempting to load the module with a different name will result in the following
error:
> apache2: Syntax error on line 129 of /etc/apache2/httpd.conf: Can't locate API module structure `secure_status_module' in file /usr/lib64/apache2/modules/mod_secure_status.so: /usr/lib64/apache2/modules/mod_secure_status.so: undefined symbol: secure_status_module

Again, this is an intentional safety feature to force the behaviour just noted.

## Bonus feature!

This code also adds, to both full and machine readable modes, a count of the
number of processes awaiting graceful restart.  This might come in handy if you
want to monitor for when they've all restarted.

## Credits

The original mod_status code is directly from Apache.

Sections of code have been lifted from a version of the most excellent mod_rpaf.
Those are from http://github.com/gnif/mod_rpaf and credited to:

* Thomas Eibner <thomas@stderr.net>
* Geoffrey McRae <gnif@xbmc.org>
* Proxigence Inc. <support@proxigence.com>

Remaining craziness is either by myself or someone who has submitted a PR.
Check git blame, it's more accurate than this file.

This software is licensed under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
None of the authors are responsible for anything arising from use of this code.
