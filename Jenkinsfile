//!groovy

@Library('visibilityLibs')
import com.liaison.jenkins.common.kubernetes.*
import com.liaison.jenkins.common.servicenow.ServiceNow
import com.liaison.jenkins.common.slack.*
import com.liaison.jenkins.visibility.Utilities;

def deployments = new Deployments()
def k8sDocker = new Docker()
def kubectl = new Kubectl()
def serviceNow = new ServiceNow()
def slack = new Slack()
def utils = new Utilities();

def deployment
def dockerImageName = "visibility/hazelcast-manager";
def otbpDeployment
def otbpDockerImageName = "bpdockerhub/hazelcast-manager"

timestamps {

    node {

        stage('Check out from SCM') {

            def scmVars = checkout scm
            env.GIT_COMMIT = scmVars.GIT_COMMIT
            env.GIT_URL = scmVars.GIT_URL
            env.VERSION = utils.runSh("git describe --always")
            currentBuild.displayName  = "#${env.BUILD_NUMBER}-${env.VERSION}"

            stash name: 'workspace', includes: '**'
        }

        stage('Build Docker image (AT4D) ') {

            deployment = deployments.create(
                name: 'Hazelcast deployment',
                version: env.VERSION,
                description: 'Hazelcast deployment for Kubernetes',
                dockerImageName: dockerImageName,
                dockerImageTag: env.VERSION,
                yamlFile: 'K8sfile.yaml',   // optional, defaults to 'K8sfile.yaml'
                gitUrl: env.GIT_URL,        // optional, defaults to env.GIT_URL
                gitCommit: env.GIT_COMMIT,  // optional, defaults to env.GIT_COMMIT
                gitRef: env.VERSION,        // optional, defaults to env.GIT_COMMIT
                kubectl: kubectl
            )

            k8sDocker.build(imageName: dockerImageName);
            milestone label: 'Docker image built', ordinal: 100

            if (utils.isMasterBuild()) {
                k8sDocker.push(imageName: dockerImageName, imageTag: env.VERSION)
            }
        }
    }


    node('at4d-c3-agent') {
        
        stage('Build Docker image (OTBP) ') {
            
            unstash name: 'workspace'
            
            otbpDeployment = deployments.create(
                name: 'Hazelcast deployment',
                version: env.VERSION,
                description: 'hazelcast deployment for Kubernetes',
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
    }

    if (utils.isMasterBuild()) {

        stage ('Deploy to Kubernetes, dev namespace') {

            try {
                deployments.deploy(
                    deployment: deployment,
                    kubectl: kubectl,
                    serviceNow: serviceNow,
                    namespace: Namespace.DEVELOPMENT,
                    rollingUpdate: false
                )

                // Deploy to Brookpark.

                deployments.deploy(
                    deployment: otbpDeployment,
                    kubectl: kubectl,
                    namespace: Namespace.DEVELOPMENT,
                    rollingUpdate: true,
                    clusters: [ Cluster.OTBP ]
                )

                deployments.deploy(
                    deployment: otbpDeployment,
                    kubectl: kubectl,
                    namespace: Namespace.SIT,
                    rollingUpdate: true,
                    clusters: [ Cluster.OTBP_SIT ]
                )

            } catch(err) {
                currentBuild.result = "FAILURE";
                error "${err}"
            }
        }
/*
        stage ('Promote to QA') {
            def msg = """\
                @here: Approve promotion of <${env.JOB_URL}|${env.JOB_NAME} #${env.BUILD_NUMBER}> to QA?
                - version ${env.VERSION}
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
            def msg = """\
                @here: <${env.JOB_URL}|${env.JOB_NAME} #${env.BUILD_NUMBER}> is waiting to be accepted to QA.
                - version ${env.VERSION}
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
                    rollingUpdate: false
                )
            } catch(err) {
                currentBuild.result = "FAILURE";
                error "${err}"
            }
        }
        stage ('QA sign-off') {
            def msg = """\
                @here: <${env.JOB_URL}|${env.JOB_NAME} #${env.BUILD_NUMBER}> is waiting to be signed off to STAGING.
                - version ${env.VERSION}
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
                comment: "Docker image published to PROD registry"
            )
        
            try {
                deployments.deploy(
                    deployment: deployment,
                    kubectl: kubectl,
                    serviceNow: serviceNow,
                    namespace: Namespace.STAGING,
                    rollingUpdate: false
                )
            } catch(err) {
                currentBuild.result = "FAILURE";
                error "${err}"
            }
        }
        stage ('deploy to Kubernetes, uat namespace') {
            def msg = """\
                @here: Approve promotion of <${env.JOB_URL}|${env.JOB_NAME} #${env.BUILD_NUMBER}> to UAT?
                version ${env.VERSION}
                ServiceNow CR <${deployment.crUrl()}|${deployment.crNumber()}>
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
                        rollingUpdate: false
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
*/        
    }
}