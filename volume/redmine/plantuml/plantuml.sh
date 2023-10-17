#!/bin/bash
/usr/bin/java -Djava.io.tmpdir=/var/tmp -Djava.awt.headless=true -jar /home/redmine/plantuml.jar ${@}
