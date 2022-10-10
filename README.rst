ProcessWire - Content Management System
=======================================

`ProcessWire`_ is a free content management system (CMS) and framework (CMF) 
built to save you time and work the way you do. With all custom fields, 
a secure foundation, proven scalability and performance, ProcessWire connects
all of your content seamlessly, making your job fast, easy and fun.
Extendable with custom developed plugins, or search the availabel `third party
ProcessWire modules`_

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- ProcessWire configurations:
   
   - Installed (using composer_) from upstream source code to /var/www/processwire
   - Uploading of media such as images, videos, etc.
   - **Security note**: Major updates to ProcessWire may require
     supervision so they **ARE NOT** configured to install automatically.
     See `ProcessWire update docs` for more detail on upgrading.
               
- SSL support out of the box.
- `Adminer`_ administration frontend for MySQL (listening on port
  12322 - uses SSL).
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL (MariaDB) and Postfix.

See the `ProcessWire docs`_ for further details.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**
-  Adminer: username **adminer**
-  ProcessWire: username **admin**

.. _ProcessWire: https://www.processwire.com
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _composer: https://getcomposer.org
.. _third party ProcessWire modules: https://www.processwire.com/modules/
.. _ProcessWire update docs: https://processwire.com/docs/start/install/upgrade/
.. _Adminer: https://www.adminer.org/
.. _ProcessWire docs: https://www.processwire.com/docs/
