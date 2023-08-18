Map config = [
    defaultTargets: '6x 7x',
    defaultImageUrls: "",
    defaultWbdevImage: '',
    defaultEnableTelegramAlert: false,
    customReleaseBranchPattern: '^\b$'  // never-matching pattern
]

pipeline {
    agent {
        label 'devenv'
    }
    parameters {
        string(name: 'TARGETS', defaultValue: config.defaultTargets, description: 'space-separated list')
        string(name: 'FIT_URLS', defaultValue: config.defaultImageUrls, description: 'space-separated list')
        booleanParam(name: 'ADD_VERSION_SUFFIX', defaultValue: true, description: 'for non dev/* branches')
        booleanParam(name: 'UPLOAD_TO_POOL', defaultValue: true,
                     description: 'works only with ADD_VERSION_SUFFIX to keep staging clean')
        booleanParam(name: 'CLEAN', defaultValue: false, description: 'force cleaned on dev/* branches')
        booleanParam(name: 'FORCE_OVERWRITE', defaultValue: false, description: 'replace existing version of package in apt')
        booleanParam(name: 'REPLACE_RELEASE', defaultValue: false, description: 'replace existing github release')
        string(name: 'WBDEV_IMAGE', defaultValue: config.defaultWbdevImage, description: 'docker image path and tag')
        booleanParam(name: 'ENABLE_TELEGRAM_ALERT', defaultValue: config.defaultEnableTelegramAlert, description: 'send alert if build fails')
    }
    environment {
        RESULT_SUBDIR = 'pkgs'

        // Initialize params as envvars, workaround for bug https://issues.jenkins-ci.org/browse/JENKINS-41929
        WBDEV_IMAGE = "${params.WBDEV_IMAGE}"
    }
    stages {
        stage('Cleanup workspace') {
            steps {
                cleanWs deleteDirs: true, patterns: [[pattern: "$RESULT_SUBDIR", type: 'INCLUDE']]
            }
        }
        stage('Determine version suffix') {
            when { expression {
                params.ADD_VERSION_SUFFIX && !wb.isBranchRelease(env.BRANCH_NAME, config.customReleaseBranchPattern)
            }}

            steps {
                script {
                    def baseCommit = sh(returnStdout: true, script: '''\\
                        git log --diff-filter=A --cherry --pretty=format:"%h" -- debian/changelog''').trim()

                    def versionSuffix = sh(returnStdout: true, script: """\\
                        echo ~exp~`echo ${BRANCH_NAME} | sed -e 's/\\W/+/g' -e 's/_/+/g'`~`\\
                        git rev-list --count HEAD...${baseCommit}`~g`\\
                        git rev-parse --short HEAD`""").trim()
                    env.VERSION_SUFFIX = versionSuffix
                }
            }
        }
        stage('Setup builds') {
            steps {
                script {
                    def targets = params.TARGETS.split(' ')
                    def imageUrls = params.FIT_URLS.split(' ')

                    targets.eachWithIndex { target, i ->
                        if (i >= imageUrls.size()) {
                            error "Not enough FIT_URLS"
                        }

                        def currentTarget = target
                        def currentUrl = imageUrls[i]

                        def versionSuffix = env.VERSION_SUFFIX?:''

                        stage("Build ${currentTarget}") {
                            sh "wbdev root bash -c 'VERSION_SUFFIX=${versionSuffix} ./make_deb.sh ${currentTarget} ${currentUrl}'"
                        }
                    }
                }
            }
            post {
                always {
                    sh "mkdir -p $RESULT_SUBDIR && mv *.deb $RESULT_SUBDIR/ && wbdev root chown -R jenkins:jenkins $RESULT_SUBDIR"
                }
                success {
                    archiveArtifacts artifacts: "$RESULT_SUBDIR/*.deb"
                }
            }
        }

        stage('Setup deploy') {
            when { expression {
                params.UPLOAD_TO_POOL && params.ADD_VERSION_SUFFIX
            }}
            steps {
                wbDeploy projectSubdir: '.',
                         resultSubdir: env.RESULT_SUBDIR,
                         forceOverwrite: params.FORCE_OVERWRITE,
                         replaceRelease: params.REPLACE_RELEASE,
                         uploadJob: wb.repos.devTools.uploadJob,
                         aptlyConfig: wb.repos.devTools.aptlyConfig
            }
        }
    }
    post {
        always { script {
          if (params.ENABLE_TELEGRAM_ALERT || wb.isBranchRelease(env.BRANCH_NAME, config.customReleaseBranchPattern)) {
            wb.notifyMaybeBuildRestored()
          }
        }}
        failure { script {
          if (params.ENABLE_TELEGRAM_ALERT || wb.isBranchRelease(env.BRANCH_NAME, config.customReleaseBranchPattern)) {
            wb.notifyBuildFailed()
          }
        }}
    }
}
