
pipeline {
    agent any

    options {
        timestamps()
        timeout(time:20 , unit : "MINUTES")
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr:"20" , artifactNumToKeepStr:'5'))
    }

    stages{

        stage("Checkout"){
            steps{
                checkout scm
            }
        }

        stage("Bump version"){
            steps{
                sh './mvnw versions:set -DnewVersion=1.${BUILD_NUMBER} ' +
                        '-DgenerateBackupPoms=false'
            }
        }

        stage("Build, Test & Coverage"){
            steps{
                sh './mvnw clean verify'
            }
            post{
                always{
                    junit '**/target/surefire-reports/*.xml'

                    jacoco(
                            execPattern: 'target/jacoco.exec',
                            classPattern: 'target/classes',
                            sourcePattern: 'src/main/java',
                            inclusionPattern: '**/*.class'
                    )
                }
            }
        }

        stage("SonarQube Analysis"){
            steps{
                withCredentials([string(credentialsId:'sonar-token',
                        variable:'SONAR_TOKEN')]){
                    sh ''' 
                        ./mvnw org.sonarsource.scanner.maven:sonar-maven-plugin:5.7.0.6970:sonar \
                         -Dsonar.host.url=http://127.0.0.1:9000 \
                         -Dsonar.token=${SONAR_TOKEN}
                       '''
                }
            }
        }


    }
}