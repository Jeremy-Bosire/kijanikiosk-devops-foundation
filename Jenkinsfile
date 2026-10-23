// KijaniKiosk payments CI pipeline
//
//   Lint -> Build -> Verify (Test || Security Audit) -> Archive -> Publish
//
// Every run executes inside a pinned Node.js container, produces one tarball
// versioned <semver>-<git-sha>, fingerprints it, and publishes that exact file to
// the Nexus npm-hosted repository. Nexus is configured ALLOW_ONCE, so a version
// that has been published can never be overwritten.
//
// Infrastructure (Jenkins, Nexus, credentials) is defined in week5/friday/ci-infra.

pipeline {
    agent {
        docker {
            // Pinned: the same Node/npm/Alpine on every run, never a moving `latest`.
            image 'node:22.11.0-alpine3.20'
            // Join the CI network so the build reaches Nexus as http://nexus:8081.
            // `localhost` inside this container is the container itself (Challenge A).
            args '--network kk-ci'
        }
    }

    options {
        timeout(time: 10, unit: 'MINUTES')
        timestamps()
        // Queue rather than abort: a newer commit waits, it never cancels a running build.
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '10'))
    }

    triggers {
        pollSCM('H/2 * * * *')
    }

    environment {
        APP_DIR              = 'kijanikiosk-payments'
        PACKAGE_NAME         = 'kijanikiosk-payments'
        NEXUS_URL            = 'http://nexus:8081'
        NEXUS_BROWSE_URL     = 'http://localhost:8081'
        NEXUS_REPOSITORY     = 'npm-hosted'
        NEXUS_REGISTRY       = "${NEXUS_URL}/repository/${NEXUS_REPOSITORY}/"
        NEXUS_CREDENTIALS_ID = 'nexus-publisher'
        // The container has no writable $HOME. The cache lives in JENKINS_HOME (shared into
        // the container via --volumes-from) so cleanWs() does not throw it away every run.
        npm_config_cache     = '/var/jenkins_home/.npm-cache'
        npm_config_fund      = 'false'
        CI                   = 'true'
        // <semver from package.json>-<first 7 chars of the commit>, e.g. 1.0.0-3f9a2c1
        GIT_SHORT_SHA        = "${env.GIT_COMMIT.take(7)}"
        BASE_VERSION         = sh(script: "node -p \"require('./${APP_DIR}/package.json').version\"", returnStdout: true).trim()
        ARTIFACT_VERSION     = "${BASE_VERSION}-${GIT_SHORT_SHA}"
        TARBALL              = "${PACKAGE_NAME}-${ARTIFACT_VERSION}.tgz"
    }

    stages {
        stage('Lint') {
            // Fail fast: style and obvious-bug checks are the cheapest signal, so they run first.
            steps {
                dir(env.APP_DIR) {
                    sh '''
                        echo "Agent: $(node --version) / npm $(npm --version) on $(. /etc/os-release && echo "$PRETTY_NAME")"
                        echo "Building ${PACKAGE_NAME}@${ARTIFACT_VERSION} from commit ${GIT_COMMIT}"
                        npm ci --prefer-offline --no-audit
                        npm run lint
                    '''
                }
            }
        }

        stage('Build') {
            steps {
                dir(env.APP_DIR) {
                    sh '''
                        npm version "${ARTIFACT_VERSION}" --no-git-tag-version
                        npm run build
                        cat dist/build-info.json
                    '''
                }
            }
        }

        stage('Verify') {
            // Both branches always run to completion so one build reports every problem.
            parallel {
                stage('Test') {
                    steps {
                        dir(env.APP_DIR) {
                            sh 'npm run test:ci'
                        }
                    }
                }
                stage('Security Audit') {
                    steps {
                        dir(env.APP_DIR) {
                            // Fails on any high or critical advisory in the locked dependency tree.
                            sh 'npm audit --audit-level=high'
                        }
                    }
                }
            }
        }

        stage('Archive') {
            steps {
                dir(env.APP_DIR) {
                    sh '''
                        npm pack
                        echo "Tarball contents:"
                        tar -tzf "${TARBALL}"
                        # The artifact must contain the build output, not just package metadata.
                        tar -tzf "${TARBALL}" | grep -qx 'package/dist/index.js'
                        tar -tzf "${TARBALL}" | grep -qx 'package/dist/build-info.json'
                        sha256sum "${TARBALL}" | tee "${TARBALL}.sha256"
                    '''
                }
                archiveArtifacts artifacts: "${APP_DIR}/${TARBALL}, ${APP_DIR}/${TARBALL}.sha256",
                                 fingerprint: true,
                                 onlyIfSuccessful: true
            }
        }

        stage('Publish') {
            steps {
                dir(env.APP_DIR) {
                    withCredentials([usernamePassword(credentialsId: env.NEXUS_CREDENTIALS_ID,
                                                      usernameVariable: 'NEXUS_USER',
                                                      passwordVariable: 'NEXUS_PASS')]) {
                        // Single-quoted: the shell expands the secrets, Groovy never sees them.
                        // .npmrc is created and removed inside this one sh step; the trap
                        // removes it even when npm publish fails.
                        sh '''
                            set +x   # no command tracing while the auth string exists
                            set -eu
                            trap 'rm -f .npmrc' EXIT
                            NEXUS_AUTH=$(printf '%s:%s' "$NEXUS_USER" "$NEXUS_PASS" | base64 | tr -d '\\n')
                            printf '//%s:_auth=%s\\n' "${NEXUS_REGISTRY#http://}" "$NEXUS_AUTH" > .npmrc
                            echo "Publishing ${TARBALL} to ${NEXUS_REGISTRY} as ${NEXUS_USER}"
                            npm publish "${TARBALL}" --registry "${NEXUS_REGISTRY}" --tag latest
                            rm -f .npmrc
                            test ! -e .npmrc && echo ".npmrc removed"
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            junit testResults: "${APP_DIR}/reports/junit.xml", allowEmptyResults: true
            echo "Total pipeline runtime: ${currentBuild.durationString.replace(' and counting', '')}"
            cleanWs()
        }
        success {
            echo "ARTIFACT PUBLISHED: ${PACKAGE_NAME}@${ARTIFACT_VERSION}"
            echo "  Install : npm install ${PACKAGE_NAME}@${ARTIFACT_VERSION} --registry ${NEXUS_BROWSE_URL}/repository/${NEXUS_REPOSITORY}/"
            echo "  Tarball : ${NEXUS_BROWSE_URL}/repository/${NEXUS_REPOSITORY}/${PACKAGE_NAME}/-/${TARBALL}"
            echo "  Browse  : ${NEXUS_BROWSE_URL}/#browse/browse:${NEXUS_REPOSITORY}"
        }
        failure {
            echo """FAILURE NOTIFICATION: ${env.JOB_NAME} #${env.BUILD_NUMBER} failed.
  Commit  : ${env.GIT_COMMIT}
  Version : ${env.ARTIFACT_VERSION} was NOT published
  Details : ${env.BUILD_URL}console"""
        }
        changed {
            echo "STATUS CHANGE: ${env.JOB_NAME} went from ${currentBuild.previousBuild?.result ?: 'NONE'} to ${currentBuild.currentResult} at #${env.BUILD_NUMBER}"
        }
    }
}
