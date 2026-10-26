
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


    }
}