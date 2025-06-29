Map config = [
    defaultTargets: '6x 7x 8x',
    wbReleases: ['stable', 'testing'],
    defaultImageUrls: "",
    defaultFitBuildIds: "14311 14312 14310",
    defaultWbdevImage: 'registry.wirenboard.lan/contactless/devenv_test:trixie',
    defaultEnableTelegramAlert: false,
    customReleaseBranchPattern: '^\b$'  // never-matching pattern
]

pipeline {
    agent {
        label 'devenv'
    }
    parameters {
        string(name: 'TARGETS', defaultValue: config.defaultTargets, description: 'space-separated list')
        choice(name: 'WB_RELEASE', choices: config.wbReleases, description: 'wirenboard release (from WB repo)')
        string(name: 'FIT_URLS', defaultValue: config.defaultImageUrls, description: 'space-separated list (leave empty for latest.fit)')
        string(name: 'FIT_BUILD_IDS', defaultValue: config.defaultFitBuildIds,
               description: 'space-separated list of pipelines/build-image build IDs (takes precedence over FIT_URLS)')
        string(name: 'TESTING_SET', defaultValue: '', description: 'add testing set')
        booleanParam(name: 'ADD_VERSION_SUFFIX', defaultValue: true, description: 'for non dev/* branches')
        booleanParam(name: 'UPLOAD_TO_POOL', defaultValue: true,
                     description: 'works only with ADD_VERSION_SUFFIX to keep staging clean')
        booleanParam(name: 'FORCE_OVERWRITE', defaultValue: false, description: 'replace existing version of package in apt')
        booleanParam(name: 'PUBLISH_RELEASE', defaultValue: true, description: 'publish github release')
        booleanParam(name: 'REPLACE_RELEASE', defaultValue: false, description: 'replace existing github release')
        string(name: 'WBDEV_IMAGE', defaultValue: config.defaultWbdevImage, description: 'docker image path and tag')
        booleanParam(name: 'ENABLE_TELEGRAM_ALERT', defaultValue: config.defaultEnableTelegramAlert, description: 'send alert if build fails')
    }
    environment {
        RESULT_SUBDIR = 'pkgs'
        IMAGE_SUBDIR = 'image'

        // Initialize params as envvars, workaround for bug https://issues.jenkins-ci.org/browse/JENKINS-41929
        WBDEV_IMAGE = "${params.WBDEV_IMAGE}"
    }
    stages {
        stage('Cleanup workspace') {
            steps {
                cleanWs deleteDirs: true, patterns: [[pattern: "$RESULT_SUBDIR", type: 'INCLUDE']]
                cleanWs deleteDirs: true, patterns: [[pattern: "$IMAGE_SUBDIR", type: 'INCLUDE']]
            }
        }
        stage('Determine version suffix') {
            when { expression {
                params.ADD_VERSION_SUFFIX && !wb.isBranchRelease(env.BRANCH_NAME, config.customReleaseBranchPattern)
            }}

            steps {
                script {
                    env.VERSION_SUFFIX = wb.makeVersionSuffixFromBranch(wb.getMainBranchName())
                }
            }
        }
        stage('Collect FIT from build') {
            when { expression {
                params.FIT_BUILD_IDS?.trim()
            }}
            steps {
                script {
                    def targets = params.TARGETS.split(' ')
                    def fitBuildIds = params.FIT_BUILD_IDS.split(' ')

                    targets.eachWithIndex { target, i ->
                        def currentBuildId = ''
                        if (i < fitBuildIds.size()) {
                            currentBuildId = fitBuildIds[i]
                        }

                        if (currentBuildId?.trim()) {
                            def targetImageDir = "${env.IMAGE_SUBDIR}/${target}"
                            copyArtifacts(
                                projectName: 'pipelines/build-image',
                                selector: specific(currentBuildId.trim()),
                                filter: 'jenkins_output/*.fit',
                                target: targetImageDir,
                                flatten: true,
                                fingerprintArtifacts: true
                            )
                        }
                    }
                }
            }
        }
        stage('Setup builds') {
            steps {
                script {
                    def targets = params.TARGETS.split(' ')
                    def imageUrls = params.FIT_URLS.split(' ')

                    targets.eachWithIndex { target, i ->
                        def currentUrl = ''
                        if (i < imageUrls.size()) {
                            currentUrl = imageUrls[i]
                        }

                        def currentTarget = target
                        def fitSource = currentUrl

                        def localFitFile = sh(returnStdout: true,
                                              script: "first_fit=\$(ls -1 ${env.IMAGE_SUBDIR}/${currentTarget}/*.fit 2>/dev/null | head -n1); if [ -n \"\$first_fit\" ]; then readlink -f \"\$first_fit\"; fi").trim()
                        if (localFitFile) {
                            fitSource = localFitFile
                        }

                        def versionSuffix = env.VERSION_SUFFIX?:''

                        stage("Build ${currentTarget}") {
                            sh "wbdev root bash -c 'TESTING_SET=${params.TESTING_SET} VERSION_SUFFIX=${versionSuffix} WB_RELEASE=${params.WB_RELEASE} ./make_deb.sh ${currentTarget} ${fitSource}'"
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
                         withGithubRelease: params.PUBLISH_RELEASE,
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
