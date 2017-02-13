Example Java webapp infrastructure for Continuous Delivery 
============================================================
This is an example of a Java webapp project which supports techniques for continuous delivery.

Core concepts are:

* Embedded Jetty webapp for lightweight configuration, ease of use and single self contained deployment of a single binary to any environment.
* Scripted deployment of the app which supports both push and pull deployment.

Content:
--------
* settings.xml.example: Example settings.xml. Rename and put in ~/.m2.
* pom.xml: Parent pom for the entire project.
* database/: Contains code for generating DB schema with Liquibase.
* core/: Domain objects and Dao's.
* webapp/: Embedded Jetty webapp artifact. Contains the deployable webapp artifact.
* scripts/: Contains scripts for deploying, starting and monitoring of the webapp.
* config/: Contains config for the app and the deploy script.

Preconditions:
--------------
* CI environment (e. g. Jenkins)
* Artifact repository (e. g. Nexus)
* Database (e. g. MySQL)

Usage:
------
* Build it: <code>mvn clean install</code>
* See Readme.md in sub projects for usage of the different artifacts.

Releasing:
----------
* <code>mvn release:prepare -DdryRun=true -Dintegration=false</deploy>
* <code>mvn release:clean release:prepare release:perform -Dintegration=false -Dgoals=deploy</code>

Skipping targets:
-----------------
The following options are available to skip certain targets:

* <code>-DskipTests</code> (skip all tests)
* <code>-Dintegration=false</code> (skip all integration tests)
* <code>-DskipAssembly</code> (skip war packaging, appassembler and zip assembly)

This  project is downloaded from http://www.java2s.com/Open-Source/Java_Free_Code/Web_Application/Download_Continuous_Delivery_example_Free_Java_Code.htm
