# Build a Production Virtual Machine
*THESE NOTES AREN'T COMPLETE.  FOR NOW, THIS IS A STUB PAGE.*

## Significant differences from the development VM
- Asset management tools like YUI compressor, Compass, and SASS may not be necessary depending on the deployment process. This would also mean that Java and/or Ruby aren't required.
- Nginx should NOT have a default fallback host configured, since this provides a security risk.  Nginx should only respond to domains that are explicitly configured.
- All the Virtualbox host/guest setup is irrelevant on a production server.
- Code will need to be deployed to the server, instead of shared from a Virtualbox host
