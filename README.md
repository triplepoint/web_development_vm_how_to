# Development VM How-To

## Introduction
The purpose of this guide is to explain how to build simple but usable PHP servers suitable for both local development and production servers.  In writing the guide, I've chosen to build most of the major tools from source in order to track those projects' development more closely.

## Not for Everyone
While I've tried to build tools that would be broadly useful for most PHP web developers, I've also tailored these machines in places to make them more useful for my own work.  In addition, because I use these servers myself, there may be continuing changes as time goes on.  My hope in publishing this work is that someone out there finds it a useful starting place with which to build their own tools, but let me offer caution - this guide is almost certainly going to require modification in order for you to use it well.  As such, I've been wordier than a simple "copy and paste these commands" guide would typically have been so that hopefully you can understand the why as well as the what.  Please, feel free to contact me with any questions.

## Automation
I've tried to provide both a manual walk-through and an automated makefile version of all the instructions in this guide.  While I've taken care to keep the manual and automated builds similar, there are almost certainly differences.  The outcome, however, should be reasonably similar in all the ways that count.  Please file an issue ticket for any significant deviations you find.

In addition to the makefile automation, I've provided a simple Vagrant wrapper which manages the creation of new virtual machines and the execution of the makefiles on them.  See the individual server guide articles below for notes on how to use these tools.  There are almost certainly quicker ways to build Vagrant boxes than spawning a vanilla box and running a giant makefile on it, but I wanted to preserve the "understand what's going on" nature of this guide instead of just offering a prebuilt Vagrant box.

## Server Variations
While it's ideal to develop projects in an environemnt which is identical to the production environment to which they'll be deployed, there are always unavoidable considerations which force deviations.  Here are the two variations I use:
- [Development Local Virtual Machine](docs/development_vm.md)
- [Production Server Virtual Machine](docs/production_vm.md)

## Project Configuration
This guide is intended to cover the creation and setup of the servers, but intentionally stops without covering any project-specific installation details.  For things like Drupal and Wordpress, there are far better guides out there which I'm sure you can find.

The only guidance I'll offer for project setup is in the attached `project.makefile.example` which gives the beginnings of a template which you can copy into your project.
