# PHP Web Development Virtual Machine How-To

## Introduction
The purpose of this guide is to explain how to build simple but usable PHP servers suitable for both local development and production servers.  In writing this guide, I've chosen to build most of the major tools from source in order to track those projects' development more closely.

## Not for Everyone
While I've tried to build tools that would be broadly useful for most PHP developers, I've also tailored these machines in places to make them more useful for my own work.  In addition, because I use these servers myself, there may be continuing changes as time goes on.  My hope in publishing this work is that someone out there finds it to be a useful starting place with which to build their own tools, but be careful - the steps in this guide are almost certainly going to require modification in order for you to use them well.  As such, I've frequently been wordier than a typical "copy and paste these commands into your terminal" guide would have been so that hopefully you can understand the why as well as the what.  Please, feel free to contact me with any questions.

## Automation
I've tried to provide both a manual walk-through and an automated makefile version of all the instructions in this guide.  While I've taken care to keep the manual and automated builds similar, there are almost certainly differences.  The outcome, however, should be reasonably similar in all the ways that count.  Please file an issue ticket for any significant deviations you find.

In addition to the makefile automation, I've provided a simple Vagrant wrapper which manages the creation of new virtual machines and the execution of the makefiles on them.  See the individual server guide articles below for notes on how to use these tools.  There are certainly quicker ways to build Vagrant boxes than spawning a vanilla box and running a build-from-source makefile on it, but I wanted to preserve the "understand what's going on" nature of this guide instead of just offering a prebuilt Vagrant box.

## Server Variations
I'd rather not get into the practice of supporting multiple variations on this guide, but it's entirely possible that I'll want to modify these instructions and maintain more than one machine.  Here are the build instructions I've written to date:
- [PHP and Nginx Web Server Virtual Machine](docs/php_nginx_vm.md)

## Project Configuration
This guide is intended to cover the creation and setup of the servers, but intentionally stops without covering any project-specific installation details.  For things like Drupal and Wordpress, there are far better guides out there which I'm sure you can find.

The only guidance I'll offer for project setup is in the attached `project.makefile.example` which gives the beginnings of an installation makefile which you can copy into your project.  It primarily deals with self-signed SSL certificates and Nginx configuration.

[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/triplepoint/web_development_vm_how_to/trend.png)](https://bitdeli.com/free "Bitdeli Badge")
