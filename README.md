Docker Envoy
============

This readme is a work in progress...


Docker provides a way of running applications in an isolated and dependable environment. Envoy takes this isolation a step further and helps you run your docker image builds and tests in isolation as well.

This can be helpful for when the environment building your images is not under your control and your build step has dependencies as well (ie - JDK). This uses docker at build time to help create...

For example with envoy lets say you need the whole JDK to build your image, but your only the JRE to run it. Envoy allows you to define a JDK image that is used in an intermediate step to build that final runnable JRE image.

It does the same for testing, by allowing you to pull whatever test libraries you need into a container and run those tests there instead of polluting the host.

Additionally Envoy is most helpful for managing a group of projects instead of a single one. It follows a structural project layout....

Requirements
------------
* docker >= 1.12
* docker-compose >= 1.8
* git

Make sure Docker is configured to run [without sudo](https://docs.docker.com/engine/installation/linux/ubuntulinux/#/create-a-docker-group).

For example if you are using Ubuntu 16, these instructions might get you setup:

	sudo apt-get update
	sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
	sudo apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'
	sudo apt-get update
	sudo apt-get install -y docker-engine git
	sudo usermod -aG docker $(whoami)

You will need to log out and back in as the same user to enable this change. Now, to see that docker is setup correctly:

	docker run hello-world

Installation
------------

Lets presume you have a directory with your dockerfiles projects in /path/to/dockerfiles

Configure your project to use envoy

    cd /path/to/envoy
    cp envoy-config.sample.sh /path/to/dockerfiles/envoy-config.sh
    cp nv /path/to/dockerfiles/nv

Edit your envoy-config.sh if you need to. Now you should be able to execute the `nv` script in your project.

In the config you should set GIT_REMOTE_BASE and ENVOY. If you dont want to set is there, you can set an environment variable ENVOY to the absolute path of this directory. For example you can put this in your .bashrc

    export ENVOY=/path/to/envoy


Use
---

After installation the `nv` script in your project can be used to build images, build a stack, test a stack, or control a stack. Run the `nv` script for a list of options.


Sample
------

TODO: import https://github.com/docker/example-voting-app perhaps?

For now you can see it in action here: https://github.com/PLOS/Dockerfiles


Building images
---------------

The _build.sh_ script can be used to build single images or whole stacks.

Note that images are tagged with the git branch you have checked out for that project. For example if you build rhino while you have the development branch checked out, it will create a rhino:development image. configurations files refer to specific branches.... (finish this)

Image builds will only work for projects you have the source code locally checked out for, but the builder script will do its best to clone git project repos that it needs source code for.


Testing your Dockerfiles
------------------------

See the tests/ directory. These are not exhaustive service tests. They are supposed to test your containers, such that you can update the Dockerfiles and be sure that it does not break anything. Tests themselves run in the 'testrunner' container so testing requirements are isolated from the host.


Development Conventions
-----------------------

For each project the images created for it should be tagged with a version number and with the name of the git branch.

In each image, create a file at /root/version.txt that contains the version number representing the built artifacts. For example, "0.5.0-SNAPSHOT".

Here are some of the files you will find in each of the project directories, and what they are used for:

__build-image.sh__ - Builds an image from the source code of the project

__compile.sh__ - An intermediate build container is used before the final image is created. This script performs inside that container what is needed to turn your project source code into its compiled assets (commonly .war files) and then collects additional files (commonly config files and database migrations) into a common place so the runnable image can grab them.

__Dockerfile__ - The Dockerfile for the runnable image of the project

__run.sh__ - The script that is run in the foreground inside your container. This commonly consists of seeding the database, processing configuration templates, and running a service like tomcat.

__(configuration templates)__ - You will see various files (ie - context.xml) in project directories. These are specific to that project and are simple templates that are processed at run time with whatever environment variables were set (most commonly in the docker-compose file).
