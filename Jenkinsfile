pipeline {
    agent any

    environment{
        IMAGE_NAME = 'school-backend-app'
    }

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
            when { branch 'main'}
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

        stage("Deploy to Nexus") {
            when { branch 'main'}
            steps {
                withCredentials([usernamePassword(credentialsId: 'nexus-creds', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                    writeFile file: 'settings.xml', text: """<settings>
                        <servers>
                            <server>
                                <id>deploymentRepo</id>
                                <username>${NEXUS_USER}</username>
                                <password>${NEXUS_PASS}</password>
                            </server>
                        </servers>
                    </settings>
                    """
                    sh '''
                        ./mvnw deploy \
                            -DskipTests \
                            -s settings.xml \
                            -DaltDeploymentRepository=deploymentRepo::default::http://127.0.0.1:8081/repository/maven-releases/
                    '''
                }
            }
        }

        stage("Docker build"){
            steps{
                sh "docker build -t ${IMAGE_NAME}:1.${BUILD_NUMBER} ."
                sh "docker tag ${IMAGE_NAME}:1.${BUILD_NUMBER} " +
                        "${IMAGE_NAME}:latest"
            }
        }
    }

    post {
        success {
            echo 'PIPELINE STATUS : SUCCESS'

            // Slack Success Notification
            slackSend(
                    color: 'good',
                    message: "✅ SUCCESS: Job '${env.JOB_NAME}' [Build #${env.BUILD_NUMBER}] passed successfully. (<${env.BUILD_URL}|Open in Jenkins>)"
            )


            // Email Success Notification
            emailext(
                    subject: "SUCCESS: Job '${env.JOB_NAME} [ #${env.BUILD_NUMBER} ]'",
                    body: "The build passed successfully!\n\nView results in Jenkins: ${env.BUILD_URL}",
                    to: "imedjadli@proton.me"
            )
        }

        failure {
            echo 'PIPELINE STATUS : FAILED'

            // Slack Failure Notification
            slackSend(
                    color: 'danger',
                    message: "❌ FAILED: Job '${env.JOB_NAME}' [Build #${env.BUILD_NUMBER}] failed. (<${env.BUILD_URL}|Open in Jenkins>)"
            )

            // Email Failure Notification
            emailext(
                    subject: "FAILED: Job '${env.JOB_NAME} [ #${env.BUILD_NUMBER} ]'",
                    body: "The build has failed. Please check the logs.\n\nConsole output: ${env.BUILD_URL}",
                    to: "imedjadli@proton.me"
            )
        }

        always {
            echo 'PIPELINE TERMINE'
        }

        cleanup {
            deleteDir()
        }
    }
}