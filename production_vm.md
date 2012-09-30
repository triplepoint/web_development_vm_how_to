# BUILD A NEW PRODUCTION VIRTUAL MACHINE
THESE NOTES AREN'T COMPLETE YET.  FOR NOW, THIS IS A STUB PAGE.

## Significant differences from the development VM
- Asset management tools like YUI compressor, compass, and SASS may not be necessary depending on the deployment process.
    This would also mean that Java and Ruby also aren't required.
- Nginx should NOT have a default fallback host configured, since this provides a security risk.  Nginx should only respond
    to domains that explicitly configured.
- SSL certificates probably shouldn't be self-signed in production, except for the absolute simplest of implementations.
- All the virtualbox host/guest stuff is irrelevant on a production server.
- Code will need to be deployed to the server, instead of shared from a virtualbox host
