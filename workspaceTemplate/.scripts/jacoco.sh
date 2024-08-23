reportfiles=""
file="$1"
while read arg; do
  if [[ -n "$arg" ]]
  then
  	reportfiles="${reportfiles} --classfiles ./bin/${arg}"
  fi
done < "$file"

rm -Rf jacoco
shopt -s globstar

if javac --release 11 -d bin -cp ./.lib/*:./src/.lib/* ./src/**/*.java > /dev/null
then
	if java -javaagent:./.lib/jacocoagent.jar=append=false,destfile=./.reports/jacoco.exec -jar ./.lib/junit-platform-console-standalone-1.10.1.jar execute --include-engine=junit-jupiter --class-path bin:./src/.lib/* --scan-classpath > /dev/null
	then
		if java -jar ./.lib/jacococli.jar report ./.reports/jacoco.exec ${reportfiles} --sourcefiles ./src/main --html ./jacoco > /dev/null 
		then
			echo -e "Jacoco report generation successful!\n"
			exit 0
		else
			echo -e "Jacoco report generation failed - unknown error!\n"
			exit 1
		fi

	else
		echo -e "Jacoco report generation failed - all unit tests must pass!\n"
		exit 2
	fi
else
	echo -e "Jacoco report generation failed - test class(es) did not compile!\n"
	exit 3
fi 