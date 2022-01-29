#!/usr/bin/python3
"""Set ProcessWire admin password and email

Option:
    --pass=     unless provided, will ask interactively
    --email=    unless provided, will ask interactively
"""

import sys
import getopt
import hashlib
import subprocess

from libinithooks.dialog_wrapper import Dialog
from mysqlconf import MySQL


def usage(s=None):
    if s:
        print("Error:", s, file=sys.stderr)
    print("Syntax: %s [options]" % sys.argv[0], file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass=', 'email='])
    except getopt.GetoptError as e:
        usage(e)

    password = ""
    email = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val
        elif opt == '--email':
            email = val

    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')
        password = d.get_password(
            "ProcessWire Password",
            "Enter new password for the ProcessWire 'admin' account.")

    if not email:
        if 'd' not in locals():
            d = Dialog('TurnKey Linux - First boot configuration')

        email = d.get_email(
            "ProcessWire Email",
            "Please enter email address for the ProcessWire 'admin' account.",
            "admin@example.com")

    m = MySQL()
    m.execute('UPDATE processwire.field_email SET data=\"%s\" WHERE data=\"admin@example.com\";' % email)

    subprocess.call(["/usr/lib/inithooks/bin/pwBootstrap.sh", password])

if __name__ == "__main__":
    main()

