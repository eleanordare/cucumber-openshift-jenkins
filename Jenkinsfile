print "=========================================================="
print "                    Cucumber Testing"
print "=========================================================="

node('jenkins-agent'){

  workspace = pwd()   // Set the main workspace in your Jenkins agent

  authToken = ""      // Get your user auth token for OpenShift
  apiURL = ""         // URL for your OpenShift cluster API

  gitUser = ""        // Set your Git username
  gitPass = ""        // Set your Git password
  gitURL = ""         // Set the URL of your test suite repo
  gitName = ""        // Set the name of your test suite repo
  gitBranch = ""      // Set the branch of your test suite repo

  jenkinsUser = ""    // Set username for Jenkins
  jenkinsPass = ""    // Set API token for Jenkins

  // Set location of OpenShift objects in workspace
  buildConfigPath = "${workspace}/${gitName}/ocp/build-config.yaml"
  imageStreamPath = "${workspace}/${gitName}/ocp/image-stream.yaml"
  jobTemplatePath = "${workspace}/${gitName}/ocp/job-template.yaml"

  project = ""    // Set the OpenShift project you're working in
  testSuiteName = "cucumber-test-suite"   // Name of the job/build/imagestream

  // Login to the OpenShift cluster
  sh """
      set +x
      oc login --insecure-skip-tls-verify=true --token=${authToken} ${apiURL}
  """

  // Checkout the test suite repo into your Jenkins agent workspace
  int slashIdx = gitURL.indexOf("://")
  String urlWithCreds = gitURL.substring(0, slashIdx + 3) +
          "\"${gitUser}:${gitPass}\"@" + gitURL.substring(slashIdx + 3);

  sh """
    rm -rf ${workspace}/${gitName}
    git clone -b ${gitBranch} ${urlWithCreds} ${gitName}
    echo `pwd && ls -l`
  """

  // Create your ImageStream and BuildConfig in OpenShift
  // Then start the build for the test suite image
  sh """
    oc apply -f ${imageStreamPath} -n ${project}
    oc apply -f ${buildConfigPath} -n ${project}
    oc start-build ${testSuiteName} -n ${project} --follow
  """

  // Get test suite image from correct cluster & project
  String imageURL = sh (
    script:"""
      oc get is/${testSuiteName} -n ${project} --output=jsonpath={.status.dockerImageRepository}
      """,
    returnStdout: true
  )

  // Set the return URL for the Jenkins input step
  inputURL = env.BUILD_URL + "input/Cucumber/proceedEmpty"

  // Delete existing test suite job for previous test run
  // Create new test suite job with latest image
  // Pass in input URL, Jenkins username/password, and image
  sh """
  oc delete job/${testSuiteName} -n ${project} --ignore-not-found=true
  oc process -f ${jobTemplatePath} -p \
    JENKINS_PIPELINE_RETURN_URL=${inputURL} \
    USER_NAME=${jenkinsUser} \
    PASSWORD=${jenkinsPass} \
    IMAGE=${imageURL}:latest \
    -n ${project} | oc create -f - -n ${project}
  """

  // Get list of all running pods in your OpenShift project
  String podResults = sh (
       script:"""
         oc get pods -n ${project} --output=name
       """,
       returnStdout: true
  )

  // Get job logs and exit upon job completion
  // If job pod hasn't spun up yet, waits 5s and tries again
  // If job pod hasn't spun up after 10 tries, fails
  numTry = 0
  podList = podResults.split('\n')
  for (int x = 0; x < podList.size(); x++){
   String pod = podList[x]
   // Look for running test suite job and not the build pod
   if(pod.contains("${testSuiteName}") && !pod.contains("build")){
     while(numTry < 10){
       try {
         sh """
           sleep 5s
           oc logs ${pod} -n ${project}
         """
         numTry = 11
       } catch(e) {
           print e
           numTry++
           print "Checking if job container is up and running..."
       }
     }
     if(numTry == 10) {
       error("Job did not spin up in ${project}.")
     }
     jobPod = pod
   }
  }

  // Get succinct pod name
  jobPod = jobPod.replaceAll("pod/","")

  // Print a link to the test suite job in OpenShift
  print "Watch the test suite logs as they run here:"
  print "${apiURL}/console/project/${project}/browse/pods/${jobPod}?tab=logs"

  // Run two branches in parallel:
  //  - one waits for the job to return and gets the test results
  //  - the other follows the logs of the test suite pod
  def testingBranches = [:]

  testingBranches["input"] = {

    // Create an input step that will be called by the test suite job
    // This will let Jenkins know that it's time to retrieve the Cucumber results
    print "Please don't click Proceed. The OpenShift pod will call Jenkins when the tests have completed."
    input id: "Cucumber", message: "Waiting for testing to finish..."

    // Copy the results folder from the test suite pod to the Jenkins agent
    print "Retrieving Cucumber results files from pod..."
    sh """
      oc rsync ${jobPod}:/tmp/src/reports . -n ${project}
    """

    print "=========================================================="
    print "                    Cucumber Reports"
    print "=========================================================="

    // Cucumber Reports Plugin parses the JSON files
    // Uses "reports" directory copied from test suite pod
    step([$class: 'CucumberReportPublisher',
           jenkinsBasePath: '',
           fileIncludePattern: '',
           fileExcludePattern: '',
           jsonReportDirectory: 'reports',
           ignoreFailedTests: true,
           missingFails: false,
           pendingFails: false,
           skippedFails: false,
           undefinedFails: false,
           parallelTesting: false])

    // Cucumber Reports Plugin charts/graphs at this link
    print "Cucumber test results available here:"
    def intTestURL = env.BUILD_URL + "cucumber-html-reports/overview-features.html"
    print intTestURL

  } // branch for input

  testingBranches["logs"] = {

    print "=========================================================="
    print "                     Test Suite Logs"
    print "=========================================================="

    // Print test suite logs as they happen
    // This branch will exit after the "sleep 1m" in runjob.sh
    sh """
      oc logs -f ${jobPod} -n ${project}
    """

  } // branch for logs

  // Runs the two branches in parallel
  parallel testingBranches

} // node
