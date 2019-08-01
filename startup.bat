cd /D "%~dp0"
set MAVEN_OPTS="-Xmx4096m"
mvn exec:java -Pstart 
