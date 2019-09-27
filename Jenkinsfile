#!groovy

@Library('visibilityLibs')
import com.liaison.jenkins.visibility.Utilities;
import com.liaison.jenkins.common.testreport.TestResultsUploader
import com.liaison.jenkins.common.sonarqube.QualityGate
import com.liaison.jenkins.common.kubernetes.*
import com.liaison.jenkins.common.e2etest.*
import com.liaison.jenkins.common.servicenow.ServiceNow
import com.liaison.jenkins.common.slack.*
import com.liaison.jenkins.common.releasenote.ReleaseNote


def deployments = new Deployments()
def k8sDocker = new Docker()
def kubectl = new Kubectl()
def serviceNow = new ServiceNow()
def slack = new Slack()

def utils = new Utilities()
def uploadUtil = new TestResultsUploader()
def qg = new QualityGate()
def e2etest = new E2eTestDeployer()
def testSessions = new TestSessions()
def release = new ReleaseNote()

def deployment
def otbpDeployment
def dockerImageName = "content-metadata-injector"
def otbpDockerImageName = "bpdockerhub/content-metadata-injector"

timestamps {
    node {
/*
        stage('Checkout') {
            def scmVars = checkout scm
            env.VERSION = utils.runSh("grep '## \\[[0-9]' CHANGELOG.md | head -n 1 | cut -d '[' -f2 | cut -d ']' -f1").trim()
            env.GIT_COMMIT = scmVars.GIT_COMMIT
            env.GIT_URL = scmVars.GIT_URL
            env.REPO_NAME = utils.runSh("basename -s .git ${env.GIT_URL}")
            currentBuild.displayName  = "${env.VERSION}-${env.BUILD_NUMBER}"
        }

        stage('Build') {
            sh './mvnw clean package -u'
            stash name: 'workspace', includes: '**'
        }
*/
/*
        stage('Test') {
            sh './gradlew test consolidateTestResults'

            if (utils.isMasterBuild()) {
                def unitTestInfo = uploadUtil.uploadResults(
                    "${env.REPO_NAME}",
                    "${env.VERSION}",
                    "DEVINT",
                    "Example Unit Test Results",
                    "Unit test",
                    "UNIT",
                    ["./build/test-results/test/consolidated/TEST-Example_unit_test_results-consolidated.xml"]
                )
                UT_REPORT_URL = unitTestInfo
            }
        }

        stage('Code analysis') {
            timeout(15) {
                withSonarQubeEnv('Sonarqube-k8s') {
                    sh "./gradlew sonarqube -x test --info"
                }
            }
        }

        stage('Quality gate') {
            qgStatus = qg.checkQualityGate(env.REPO_NAME)
        }
*/
/*        
        stage('Build Docker image (AT4D)') {

            deployment = deployments.create(
                name: 'content-metadata-injector',
                version: env.VERSION,
                description: 'Deployment of content-metadata-injector',
                dockerImageName: dockerImageName,
                dockerImageTag: env.VERSION,
                yamlFile: 'K8sfile.yaml',   // optional, defaults to 'K8sfile.yaml'
                gitUrl: env.GIT_URL,        // optional, defaults to env.GIT_URL
                gitCommit: env.GIT_COMMIT,  // optional, defaults to env.GIT_COMMIT
                gitRef: env.VERSION,        // optional, defaults to env.GIT_COMMIT
                kubectl: kubectl
            )

            k8sDocker.build(imageName: dockerImageName)
            milestone label: 'Docker image built', ordinal: 100

            if (utils.isMasterBuild()) {
                k8sDocker.push(imageName: dockerImageName, imageTag: env.VERSION)
            }
        }
  */  
  }
    node('at4d-c3-kubectl') {

        stage('Checkout') {
            def scmVars = checkout scm
            env.VERSION = utils.runSh("grep '## \\[[0-9]' CHANGELOG.md | head -n 1 | cut -d '[' -f2 | cut -d ']' -f1").trim()
            env.GIT_COMMIT = scmVars.GIT_COMMIT
            env.GIT_URL = scmVars.GIT_URL
            env.JAVA_HOME="${tool 'jdk11'}"
            env.PATH="${env.JAVA_HOME}/bin:${env.PATH}"
            sh 'java -version'
            env.REPO_NAME = utils.runSh("basename -s .git ${env.GIT_URL}")
            currentBuild.displayName  = "${env.VERSION}-${env.BUILD_NUMBER}"
        }
        
         stage('Build') {
            sh './mvnw clean package -q'
            stash name: 'workspace', includes: '**'
        }        
        
        
        stage('Build Docker image (OTBP)') {
    
            unstash name: 'workspace'

            otbpDeployment = deployments.create(
                name: 'content-metadata-injector',
                version: env.VERSION,
                description: 'Deployment of content-metadata-injector',
                dockerImageName: otbpDockerImageName,
                dockerImageTag: env.VERSION,
                yamlFile: 'K8sfile.yaml',   // optional, defaults to 'K8sfile.yaml'
                gitUrl: env.GIT_URL,        // optional, defaults to env.GIT_URL
                gitCommit: env.GIT_COMMIT,  // optional, defaults to env.GIT_COMMIT
                gitRef: env.VERSION,        // optional, defaults to env.GIT_COMMIT
                kubectl: kubectl
            )

            
            k8sDocker.build(imageName: otbpDockerImageName);
            milestone label: 'OTBP Docker image built', ordinal: 101

            if (utils.isMasterBuild()) {
                k8sDocker.push(imageName: otbpDockerImageName, imageTag: env.VERSION, registry: Registry.BROOKPARK)
            }
        }

        if (utils.isMasterBuild()) {

            stage('Create release') {

                // Tag and create Github release as per SDLC:
                // https://confluence.liaison.tech/display/ARCH/SDLC-ALLOY-DEVOPS-002%3A+Change+log+and+Version+Tagging+Standard.

                release.createGithubRelease(version: "${env.VERSION}",
                    gitCommit: "${env.GIT_COMMIT}",
                    repository: "${env.REPO_NAME}",
                    dockerImageName: "${dockerImageName}:${env.VERSION}")
            }
        }
    }

    if (utils.isMasterBuild()) {

        stage ('Deploy to Kubernetes, dev namespace') {

            try {
                // Deploy to AT4D.
                
                /*
                deployments.deploy(
                    deployment: deployment,
                    kubectl: kubectl,
                    namespace: Namespace.DEVELOPMENT,
                    rollingUpdate: true     // optional, defaults to true
                )
                
                */

                // Deploy to Brookpark.
                deployments.deploy(
                    deployment: otbpDeployment,
                    kubectl: kubectl,
                    namespace: Namespace.DEVELOPMENT,
                    rollingUpdate: true,
                    clusters: [ Cluster.OTBP ]
                )
            } catch(err) {
                currentBuild.result = "FAILURE"
                error "${err}"
            }
        }
    
/*
        stage('E2E tests in DEV') {
            def testSummary
            // Because of static Alloy platforms, E2E test container deployment must happen
            // in a dedicated agent having number of executors limited to 1
            node('e2e-tests-dev') {
                def testSession = testSessions.create(
                        project: "${env.REPO_NAME}",
                        version: "${env.VERSION}",
                        title: 'Example E2E Test Results',
                        testType: 'E2E'
                )

                def githubRepository = "alloy-e2e-tests-example"
                testSummary = e2etest.runTestsInKubernetes(githubRepository, Namespace.DEVELOPMENT, testSession)
            }

            E2E_REPORT_URL = testSummary.reportUrl
            E2E_REPORT_SUMMARY = "${testSummary.status} | Success Rate: ${testSummary.successRate}% | Tests: ${testSummary.testsCount}, Passed: ${testSummary.passedCount}, Failed: ${testSummary.failureCount}, Skipped: ${testSummary.skippedCount}, Errors: ${testSummary.errorCount}."
            // Worknote must indicate if tests failed or passed
            if (testSummary.status.contains("FAILED")) {
                serviceNow.addWorknote(
                        deployment: deployment,
                        comment: "DEV E2E tests failed",
                        testResultsUrl: "${E2E_REPORT_URL}"    // optional
                )
            }
            else if (testSummary.status.contains("PASSED")) {
                serviceNow.addWorknote(
                        deployment: deployment,
                        comment: "DEV E2E tests passed",
                        testResultsUrl: "${E2E_REPORT_URL}"    // optional
                )
            }
        }

        stage ('Promote to QA') {

            def sonarProjectName = "alloy-devops-pipeline-example"
            def msg = """\
                @here: Approve promotion of <${env.JOB_URL}|${env.JOB_NAME} #${env.BUILD_NUMBER}> to QA?
                - version ${env.VERSION}
                - <${UT_REPORT_URL}|Unit Test Results>
                - <${E2E_REPORT_URL}|E2E Test Results>: ${E2E_REPORT_SUMMARY}
                - SonarQube <https://at4ch.liaison.dev/sonarqube/dashboard?id=com.liaison.alloy:${sonarProjectName}|results>
                """.stripIndent()

            def approval = slack.waitForApproval(
                channel: Slackchannel.DEV_SIGNOFF,
                message: msg,
                question: "Promote this build to QA?",
                timeoutValue: 24,       // optional, defaults to 24
                timeoutUnit: 'HOURS'    // optional, defaults to "HOURS"
            )

            if ( !approval.isApproved() ) {
                currentBuild.result = "ABORTED";
                slack.error(
                    channel: Slackchannel.DEV_SIGNOFF,
                    message: "@here: *${env.JOB_NAME} v${env.VERSION}* (build #${env.BUILD_NUMBER}) - QA deployment canceled by ${approval.user}"
                )
                serviceNow.cancel(
                    deployment: deployment,
                    comment: "QA deployment canceled by ${approval.user}"
                )
                error "QA deployment canceled by ${approval.user}"
            }

            serviceNow.promote(
                deployment: deployment,
                namespace: Namespace.QA,
                approveUser: approval.user,
                approveComment: ""      // optional, defaults to ""
            )

            milestone label: 'Promoted to QA by ${approval.user}', ordinal: 400
        }

        stage ('Accept to QA') {

            def sonarProjectName = "alloy-devops-pipeline-example"
            def msg = """\
                @here: <${env.JOB_URL}|${env.JOB_NAME} #${env.BUILD_NUMBER}> is waiting to be accepted to QA.
                - version ${env.VERSION}
                - <${UT_REPORT_URL}|Unit Test Results>
                - <${E2E_REPORT_URL}|E2E Test Results>: ${E2E_REPORT_SUMMARY}
                - SonarQube <https://at4ch.liaison.dev/sonarqube/dashboard?id=com.liaison.alloy:${sonarProjectName}|results>
                """.stripIndent()

            approval = slack.waitForApproval(
                channel: Slackchannel.QA_APPROVALS,
                message: msg,
                question: "Accept this build to QA?",
                timeoutValue: 24,       // optional, defaults to 24
                timeoutUnit: 'HOURS'    // optional, defaults to "HOURS"
            )

            if ( !approval.isApproved() ) {
                currentBuild.result = "ABORTED";
                slack.error(
                    channel: Slackchannel.QA_APPROVALS,
                    message: "@here: *${env.JOB_NAME} v${env.VERSION}* (build #${env.BUILD_NUMBER}) - QA deployment rejected by ${approval.user}"
                )
                serviceNow.cancel(
                    deployment: deployment,
                    comment: "QA deployment rejected by ${approval.user}"
                )
                error "QA deployment rejected by ${approval.user}"
            }

            milestone label: 'Accepted to QA ${approval.user}', ordinal: 600
        }

        stage ('Deploy to Kubernetes, QA namespace') {

            serviceNow.addWorknote(
                deployment: deployment,
                comment: "Accepted to QA by ${approval.user}"
            )

            try {
                deployments.deploy(
                    deployment: deployment,
                    kubectl: kubectl,
                    serviceNow: serviceNow,
                    namespace: Namespace.QA,
                    rollingUpdate: true     // optional, defaults to true
                )
            } catch(err) {
                currentBuild.result = "FAILURE";
                error "${err}"
            }
        }

        stage('E2E tests in QA') {
            def testSummary
            // Because of static Alloy platforms, E2E test container deployment must happen
            // in a dedicated agent having number of executors limited to 1
            node('e2e-tests-qa') {
                def testSession = testSessions.create(
                        project: "${env.REPO_NAME}",
                        version: "${env.VERSION}",
                        title: 'Example E2E Test Results',
                        testType: 'E2E'
                )

                def githubRepository = "alloy-e2e-tests-example"
                testSummary = e2etest.runTestsInKubernetes(githubRepository, Namespace.QA, testSession)
            }

            E2E_REPORT_URL = testSummary.reportUrl
            E2E_REPORT_SUMMARY = "${testSummary.status} | Success Rate: ${testSummary.successRate}% | Tests: ${testSummary.testsCount}, Passed: ${testSummary.passedCount}, Failed: ${testSummary.failureCount}, Skipped: ${testSummary.skippedCount}, Errors: ${testSummary.errorCount}."
            // Worknote must indicate if tests failed or passed
            if (testSummary.status.contains("FAILED")) {
                serviceNow.addWorknote(
                        deployment: deployment,
                        comment: "QA E2E tests failed",
                        testResultsUrl: "${E2E_REPORT_URL}"    // optional
                )
            }
            else if (testSummary.status.contains("PASSED")) {
                serviceNow.addWorknote(
                        deployment: deployment,
                        comment: "QA E2E tests passed",
                        testResultsUrl: "${E2E_REPORT_URL}"    // optional
                )
            }
        }

        stage('Acceptance tests') {
            //Deploy Robot Framework example test.
            def testSummary
            // Because of static Alloy platforms, E2E test container deployment must happen
            // in a dedicated agent having number of executors limited to 1
            node('e2e-tests-qa') {
                def testSession = testSessions.create(
                        project: "${env.REPO_NAME}",
                        version: "${env.VERSION}",
                        title: 'Example Robot Framework E2E Test Results',
                        testType: 'E2E',
                        includeGroups: 'exampleANDkdt'
                )

                def githubRepository = "alloy-robotframework-tests"
                testSummary = e2etest.runTestsInKubernetes(githubRepository, Namespace.QA, testSession)
            }
            ACCEPTANCE_REPORT_URL = testSummary.reportUrl
            ACCEPTANCE_REPORT_SUMMARY = "${testSummary.status} | Success Rate: ${testSummary.successRate}% | Tests: ${testSummary.testsCount}, Passed: ${testSummary.passedCount}, Failed: ${testSummary.failureCount}, Skipped: ${testSummary.skippedCount}, Errors: ${testSummary.errorCount}."
            // Worknote must indicate if tests failed or passed
            if (testSummary.status.contains("FAILED")) {
                serviceNow.addWorknote(
                        deployment: deployment,
                        comment: "QA Acceptance tests failed",
                        testResultsUrl: "${ACCEPTANCE_REPORT_URL}"    // optional
                )
            }
            else if (testSummary.status.contains("PASSED")) {
                serviceNow.addWorknote(
                        deployment: deployment,
                        comment: "QA Acceptance tests passed",
                        testResultsUrl: "${ACCEPTANCE_REPORT_URL}"    // optional
                )
            }
        }


        stage('Performance tests') {
        }

        stage ('QA sign-off') {

            def sonarProjectName = "alloy-devops-pipeline-example"
            def msg = """\
                @here: <${env.JOB_URL}|${env.JOB_NAME} #${env.BUILD_NUMBER}> is waiting to be signed off to STAGING.
                - version ${env.VERSION}
                - <${UT_REPORT_URL}|Unit Test Results>
                - <${E2E_REPORT_URL}|E2E Test Results>: ${E2E_REPORT_SUMMARY}
                - <${ACCEPTANCE_REPORT_URL}|Acceptance Test Results>: ${ACCEPTANCE_REPORT_SUMMARY}
                - SonarQube <https://at4ch.liaison.dev/sonarqube/dashboard?id=com.liaison.alloy:${sonarProjectName}|results>
                """.stripIndent()

            approval = slack.waitForApproval(
                channel: Slackchannel.QA_APPROVALS,
                message: msg,
                question: "Sign-off by QA and promote to STAGING?",
                timeoutValue: 48,       // optional, defaults to 24
                timeoutUnit: 'HOURS'    // optional, defaults to "HOURS"
            )

            if ( !approval.isApproved() ) {
                currentBuild.result = "ABORTED";
                slack.error(
                    channel: Slackchannel.QA_APPROVALS,
                    message: "@here: *${env.JOB_NAME} v${env.VERSION}* (build #${env.BUILD_NUMBER}) - QA sign-off rejected by ${approval.user}"
                )
                serviceNow.cancel(
                    deployment: deployment,
                    comment: "QA sign-off rejected by ${approval.user}"
                )
                error "QA sign-off rejected by ${approval.user}"
            }

            serviceNow.promote(
                deployment: deployment,
                namespace: Namespace.STAGING,
                approveUser: approval.user,
                approveComment: ""
            )

            // Label all stored test reports from the build as 'QA Sign-off' in the QA Reporter.
            // Call once from the pipeline. Either after QA sign-off has been approved OR after
            // Staging sign if there is such stage defined.
            uploadUtil.signOffReports("${env.REPO_NAME}", "${env.VERSION}")

            milestone label: 'QA sign-off by ${approval.user}', ordinal: 800
        }

        stage ('deploy to Kubernetes, staging namespace') {

            node {
                k8sDocker.publish(
                    imageToPublish: "${deployment.dockerImageName()}:${deployment.dockerImageTag()}",
                    publishedImageName: deployment.dockerImageName(),
                    publishedImageTag: deployment.dockerImageTag()
                )
            }

            serviceNow.addWorknote(
                deployment: deployment,
                comment: "Docker image published to PROD registry",
                testResultsUrl: "${E2E_REPORT_URL}"    // optional
            )

            try {
                deployments.deploy(
                    deployment: deployment,
                    kubectl: kubectl,
                    serviceNow: serviceNow,
                    namespace: Namespace.STAGING,
                    rollingUpdate: true     // optional, defaults to true
                )
            } catch(err) {
                currentBuild.result = "FAILURE";
                error "${err}"
            }
        }

        stage ('deploy to Kubernetes, uat namespace') {

            def sonarProjectName = "alloy-devops-pipeline-example"
            def msg = """\
                @here: Approve promotion of <${env.JOB_URL}|${env.JOB_NAME} #${env.BUILD_NUMBER}> to UAT?
                version ${env.VERSION}
                ServiceNow CR <${deployment.crUrl()}|${deployment.crNumber()}>
                SonarQube <https://at4ch.liaison.dev/sonarqube/dashboard?id=com.liaison.alloy:${sonarProjectName}|results>
                """.stripIndent()

            slack.info(
                channel: Slackchannel.AE_APPROVALS,
                message: msg
            )

            def crApproved = serviceNow.waitForApproval(correlationId: deployment.gitCommit(), namespace: Namespace.UAT)

            if( crApproved ) {
                milestone label: 'UAT approved', ordinal: 900
                try {
                    deployments.deploy(
                        deployment: deployment,
                        kubectl: kubectl,
                        serviceNow: serviceNow,
                        namespace: Namespace.UAT,
                        rollingUpdate: true     // optional, defaults to true
                    )
                } catch(err) {
                    currentBuild.result = "FAILURE";
                    error "${err}"
                }
                slack.info(
                    channel: Slackchannel.AE_APPROVALS,
                    message: "@here: *${env.JOB_NAME} v${env.VERSION}* (build #${env.BUILD_NUMBER}) was deployed to UAT."
                )
            } else {
                currentBuild.result = "ABORTED";
                slack.error(
                    channel: Slackchannel.AE_APPROVALS,
                    message: "@here: *${env.JOB_NAME} v${env.VERSION}* (build #${env.BUILD_NUMBER}) - UAT deployment rejected in ServiceNow"
                )
                error "UAT deployment rejected in ServiceNow"
            }
        }

        stage ('UAT sign-off') {

            def msg = """\
                @here: Approve promotion of <${env.JOB_URL}|${env.JOB_NAME} #${env.BUILD_NUMBER}> to PROD?
                version ${env.VERSION}
                ServiceNow CR <${deployment.crUrl()}|${deployment.crNumber()}>
                """.stripIndent()

            approval = slack.waitForApproval(
                channel: Slackchannel.DEV_SIGNOFF,
                message: msg,
                question: "Sign-off from UAT and promote to PROD",
                timeoutValue: 7,
                timeoutUnit: 'DAYS'
            )

            if ( !approval.isApproved() ) {
                currentBuild.result = "ABORTED";
                slack.error(
                    channel: Slackchannel.QA_APPROVALS,
                    message: "@here: *${env.JOB_NAME} v${env.VERSION}* (build #${env.BUILD_NUMBER}) - UAT sign-off rejected by ${approval.user}"
                )
                serviceNow.cancel(
                    deployment: deployment,
                    comment: "UAT sign-off rejected by ${approval.user}"
                )
                error "UAT sign-off rejected by ${approval.user}"
            }

            serviceNow.promote(
                deployment: deployment,
                namespace: Namespace.PRODUCTION,
                approveUser: approval.user,
                approveComment: ""
            )
        }

        stage ('deploy to Kubernetes, prod namespace') {

            def msg = """\
                @here: Approve promotion of <${env.JOB_URL}|${env.JOB_NAME} #${env.BUILD_NUMBER}> to PROD?
                version ${env.VERSION}
                ServiceNow CR <${deployment.crUrl()}|${deployment.crNumber()}>
                """.stripIndent()

            slack.info(
                channel: Slackchannel.AE_APPROVALS,
                message: msg
            )

            def crApproved = serviceNow.waitForApproval(correlationId: deployment.gitCommit(), namespace: Namespace.PRODUCTION)

            if( crApproved ) {
                milestone label: 'PROD approved', ordinal: 1000
                try {
                    deployments.deploy(
                        deployment: deployment,
                        kubectl: kubectl,
                        serviceNow: serviceNow,
                        namespace: Namespace.PRODUCTION,
                        rollingUpdate: true     // optional, defaults to true
                    )
                } catch(err) {
                    currentBuild.result = "FAILURE";
                    error "${err}"
                }
                slack.info(
                    channel: Slackchannel.AE_APPROVALS,
                    message: "@here: *${env.JOB_NAME} v${env.VERSION}* (build #${env.BUILD_NUMBER}) was deployed to PROD."
                )
            } else {
                currentBuild.result = "ABORTED";
                slack.error(
                    channel: Slackchannel.AE_APPROVALS,
                    message: "@here: *${env.JOB_NAME} v${env.VERSION}* (build #${env.BUILD_NUMBER}) - PROD deployment rejected in ServiceNow"
                )
                error "PROD deployment rejected in ServiceNow"
            }
        } */
    } 
}
