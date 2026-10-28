pipeline {
    agent any

    environment{
        IMAGE_NAME = 'school-backend-app'
        OLLAMA_URL = 'http://127.0.0.1:11434'
        OLLAMA_MODEL = 'llama3.2'
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

        stage('Prepare diagnostics') {
            steps {
                sh 'mkdir -p logs'
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

        stage("Deploy to Nexus") {
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

        stage("Container Image Scanning (Trivy)") {
            steps {
                sh "trivy image --timeout 10m --exit-code 0 --severity HIGH," +
                        "CRITICAL ${IMAGE_NAME}:1.${BUILD_NUMBER}"
            }
        }

        stage("Publish Image to Docker Hub") {
            steps {
                withCredentials([usernamePassword(credentialsId:
                        'dockerhub-creds', usernameVariable: 'DOCKER_USER' ,
                        passwordVariable: 'DOCKER_PASS')]){
                    script {
                        //  login to Docker Hub
                        sh "echo '${DOCKER_PASS}' | docker login -u '${DOCKER_USER}' --password-stdin"

                        // Tag images with your Docker Hub username prefix
                        sh "docker tag ${IMAGE_NAME}:1.${BUILD_NUMBER} ${DOCKER_USER}/${IMAGE_NAME}:1.${BUILD_NUMBER}"
                        sh "docker tag ${IMAGE_NAME}:latest ${DOCKER_USER}/${IMAGE_NAME}:latest"

                        // Push versioned tag and latest tag
                        sh "docker push ${DOCKER_USER}/${IMAGE_NAME}:1.${BUILD_NUMBER}"
                        sh "docker push ${DOCKER_USER}/${IMAGE_NAME}:latest"
                    }
                }
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

            script {
                int aiStatus = sh(
                        script: 'python3 scripts/analyze_logs.py',
                        returnStatus: true
                )

                if (aiStatus != 0) {
                    echo 'AI analyzer encountered an error.'
                }
            }

            def aiSummary = fileExists('incident-report.md')
                    ? readFile('incident-report.md').take(2500)
                    : 'AI incident report unavailable. Check Jenkins console logs.'

            slackSend(
                    color: 'danger',
                    message: "❌ FAILED: Job '${env.JOB_NAME}' " +
                            "[Build #${env.BUILD_NUMBER}] failed.\n" +
                            "AI analysis:\n${aiSummary}\n" +
                            "<${env.BUILD_URL}|Open in Jenkins>"
            )

            emailext(
                    subject: "FAILED: Job '${env.JOB_NAME} [ #${env.BUILD_NUMBER} ]'",
                    body: """The pipeline failed.

AI incident analysis:
${aiSummary}

Full console output: ${env.BUILD_URL}
See archived artifacts for the complete report and stage logs.
""",
                    to: "imedjadli@proton.me"
            )
        }

        always {
            archiveArtifacts(
                    artifacts: 'incident-report.md,logs/*.log',
                    allowEmptyArchive: true
            )
            echo 'PIPELINE TERMINE'
        }

        cleanup {
            deleteDir()
        }


        always {
            echo 'PIPELINE TERMINE'
        }

        cleanup {
            deleteDir()
        }
    }
}