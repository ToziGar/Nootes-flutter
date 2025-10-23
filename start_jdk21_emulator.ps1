$env:JAVA_HOME='C:\Program Files\Eclipse Adoptium\jdk-21.0.8.9-hotspot'
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"
firebase emulators:start --only firestore --debug
