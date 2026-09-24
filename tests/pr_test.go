// Tests in this file are run in the PR pipeline and the continuous testing pipeline
package test

import (
	"fmt"
	"log"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/common"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testschematic"
)

// Use existing resource group
const resourceGroup = "geretain-test-tfe"

// Ensure every example directory has a corresponding test
const completeExampleDir = "examples/complete"
const solutionTerraformDir = "solutions/self-hosted"

// Define a struct with fields that match the structure of the YAML data
const yamlLocation = "../common-dev-assets/common-go-assets/common-permanent-resources.yaml"

// due to postgres usage, limiting to icd regions
const regionSelectionPath = "../common-dev-assets/common-go-assets/icd-region-prefs.yaml"

var permanentResources map[string]interface{}

// TestMain will be run before any parallel tests, used to read data from yaml for use with tests
func TestMain(m *testing.M) {

	var err error
	permanentResources, err = common.LoadMapFromYaml(yamlLocation)
	if err != nil {
		log.Fatal(err)
	}

	pass := common.GetRandomPasswordWithPrefix()
	encPass := common.GetRandomPasswordWithPrefix()

	// ADD SENSITIVE VALS TO ENV
	// not adding to regular vars so not to leak the values
	setPassEnvErr := os.Setenv("TF_VAR_admin_password", pass)
	if setPassEnvErr != nil {
		log.Fatal(setPassEnvErr)
	}
	setEncPassEnvErr := os.Setenv("TF_VAR_tfe_encryption_password", encPass)
	if setEncPassEnvErr != nil {
		log.Fatal(setEncPassEnvErr)
	}
	os.Exit(m.Run())
}

func setupOptions(t *testing.T, prefix string, dir string) *testhelper.TestOptions {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:      t,
		TerraformDir: dir,
		Prefix:       prefix,
		// ResourceGroup:      resourceGroup,
		BestRegionYAMLPath: regionSelectionPath,
		TerraformVars: map[string]interface{}{
			"existing_resource_group_name": resourceGroup,
			"add_to_catalog":               false,
			"postgres_vpe_enabled":         true,
			"postgres_service_endpoints":   "private",
			"postgres_deletion_protection": false,
			"kms_key_deletion_protection":  false,
			"redis_deletion_protection":    false,
			"tfe_license_secret_crn":       permanentResources["terraform_enterprise_license_secret_crn"],
			"secrets_manager_crn":          permanentResources["secretsManagerCRN"],
		},
	})

	// NOTE ON INPUT VARS:
	// the inputs for password are added in TestMain in the ENV.

	return options
}

// Consistency test for the complete example
func TestRunCompleteExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, "tfe-complete", completeExampleDir)

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

// Upgrade test using complete example
func TestRunUpgradeExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, "tfe-upg", completeExampleDir)

	output, err := options.RunTestUpgrade()
	if !options.UpgradeTestSkipped {
		assert.Nil(t, err, "This should not have errored")
		assert.NotNil(t, output, "Expected some output")
	}
}

// Schematics test using solution
func TestRunSelfHostedSchematics(t *testing.T) {
	t.Parallel()

	options := testschematic.TestSchematicOptionsDefault(&testschematic.TestSchematicOptions{
		Testing: t,
		TarIncludePatterns: []string{
			"*.tf",
			fmt.Sprintf("%s/*.tf", solutionTerraformDir),
			fmt.Sprintf("%s/kubeconfig/README.md", solutionTerraformDir),
			fmt.Sprintf("%s/*.tf", "modules/ocp-vpc"),
			fmt.Sprintf("%s/*.tf", "modules/redis"),
			fmt.Sprintf("%s/*.tf", "modules/tfe-install"),
			fmt.Sprintf("%s/*.*", "modules/tfe-install/chart/tfe"),
			fmt.Sprintf("%s/*.tpl", "modules/tfe-install/chart/tfe/templates"),
			fmt.Sprintf("%s/*.yaml", "modules/tfe-install/chart/tfe/templates"),
			fmt.Sprintf("%s/*.sh", "modules/tfe-install/scripts"),
		},
		TemplateFolder:         solutionTerraformDir,
		BestRegionYAMLPath:     regionSelectionPath,
		Prefix:                 "tfe-da",
		ResourceGroup:          resourceGroup,
		DeleteWorkspaceOnFail:  false,
		WaitJobCompleteMinutes: 120,
	})

	password := common.GetRandomPasswordWithPrefix()
	encryptionPassword := common.GetRandomPasswordWithPrefix()

	options.TerraformVars = []testschematic.TestSchematicTerraformVar{
		{Name: "prefix", Value: options.Prefix, DataType: "string"},
		{Name: "ibmcloud_api_key", Value: options.RequiredEnvironmentVars["TF_VAR_ibmcloud_api_key"], DataType: "string", Secure: true},
		{Name: "add_to_catalog", Value: false, DataType: "bool"},
		{Name: "admin_password", Value: password, DataType: "string", Secure: true},
		{Name: "tfe_encryption_password", Value: encryptionPassword, DataType: "string", Secure: true},
		{Name: "tfe_license", Value: "__NULL__", DataType: "string"},
		{Name: "tfe_license_secret_crn", Value: permanentResources["terraform_enterprise_license_secret_crn"], DataType: "string"},
	}

	err := options.RunSchematicTest()
	if !options.UpgradeTestSkipped {
		assert.NoError(t, err, "Schematic Test had an unexpected error")
	}
}
