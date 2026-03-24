// FORGE Terraform unit tests (Terratest)
// Tests basic structural validity of FORGE Terraform modules without deploying to AWS.
//
// Usage:
//   cd tests/unit
//   go mod tidy
//   go test -v -timeout 10m ./...
//
// Note: These tests use plan-only mode (no AWS credentials required for init/validate).
// Add a -run integration flag and real AWS credentials for live deployment tests.

package forge_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// repoRoot returns the absolute path to the repository root.
func repoRoot(t *testing.T) string {
	t.Helper()
	// tests/unit is two levels below root
	cwd, err := os.Getwd()
	require.NoError(t, err)
	return filepath.Join(cwd, "../..")
}

// ---------------------------------------------------------------------------
// Module: foundation/organization
// ---------------------------------------------------------------------------

func TestOrganizationModuleInit(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: filepath.Join(repoRoot(t), "modules/foundation/organization"),
		// No vars needed for init/validate
	}

	defer terraform.Destroy(t, opts) //nolint:errcheck // cleanup is best-effort in plan tests

	_, err := terraform.InitE(t, opts)
	assert.NoError(t, err, "modules/foundation/organization: terraform init failed")

	_, err = terraform.ValidateE(t, opts)
	assert.NoError(t, err, "modules/foundation/organization: terraform validate failed")
}

// ---------------------------------------------------------------------------
// Module: foundation/scp
// ---------------------------------------------------------------------------

func TestSCPModuleInit(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: filepath.Join(repoRoot(t), "modules/foundation/scp"),
	}

	_, err := terraform.InitE(t, opts)
	assert.NoError(t, err, "modules/foundation/scp: terraform init failed")

	_, err = terraform.ValidateE(t, opts)
	assert.NoError(t, err, "modules/foundation/scp: terraform validate failed")
}

// ---------------------------------------------------------------------------
// Module: foundation/logging
// ---------------------------------------------------------------------------

func TestLoggingModuleInit(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: filepath.Join(repoRoot(t), "modules/foundation/logging"),
	}

	_, err := terraform.InitE(t, opts)
	assert.NoError(t, err, "modules/foundation/logging: terraform init failed")

	_, err = terraform.ValidateE(t, opts)
	assert.NoError(t, err, "modules/foundation/logging: terraform validate failed")
}

// ---------------------------------------------------------------------------
// Module: network/vpc-baseline
// ---------------------------------------------------------------------------

func TestVPCBaselineModuleInit(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: filepath.Join(repoRoot(t), "modules/network/vpc-baseline"),
	}

	_, err := terraform.InitE(t, opts)
	assert.NoError(t, err, "modules/network/vpc-baseline: terraform init failed")

	_, err = terraform.ValidateE(t, opts)
	assert.NoError(t, err, "modules/network/vpc-baseline: terraform validate failed")
}

// ---------------------------------------------------------------------------
// Module: identity/iam-baseline
// ---------------------------------------------------------------------------

func TestIAMBaselineModuleInit(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: filepath.Join(repoRoot(t), "modules/identity/iam-baseline"),
	}

	_, err := terraform.InitE(t, opts)
	assert.NoError(t, err, "modules/identity/iam-baseline: terraform init failed")

	_, err = terraform.ValidateE(t, opts)
	assert.NoError(t, err, "modules/identity/iam-baseline: terraform validate failed")
}

// ---------------------------------------------------------------------------
// Module: encryption/kms
// ---------------------------------------------------------------------------

func TestKMSModuleInit(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: filepath.Join(repoRoot(t), "modules/encryption/kms"),
	}

	_, err := terraform.InitE(t, opts)
	assert.NoError(t, err, "modules/encryption/kms: terraform init failed")

	_, err = terraform.ValidateE(t, opts)
	assert.NoError(t, err, "modules/encryption/kms: terraform validate failed")
}

// ---------------------------------------------------------------------------
// Module: security/config-rules
// ---------------------------------------------------------------------------

func TestConfigRulesModuleInit(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: filepath.Join(repoRoot(t), "modules/security/config-rules"),
	}

	_, err := terraform.InitE(t, opts)
	assert.NoError(t, err, "modules/security/config-rules: terraform init failed")

	_, err = terraform.ValidateE(t, opts)
	assert.NoError(t, err, "modules/security/config-rules: terraform validate failed")
}

// ---------------------------------------------------------------------------
// Example: baseline-regulated (validate full wiring)
// ---------------------------------------------------------------------------

func TestBaselineRegulatedExampleInit(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: filepath.Join(repoRoot(t), "examples/baseline-regulated"),
		Vars: map[string]interface{}{
			"org_prefix":                     "test",
			"log_archive_account_email":       "log@example.com",
			"audit_account_email":             "audit@example.com",
			"network_account_email":           "network@example.com",
			"shared_services_account_email":   "shared@example.com",
			"domain_name":                     "example.com",
			"break_glass_trusted_arns":        []string{"arn:aws:iam::123456789012:user/admin"},
		},
	}

	_, err := terraform.InitE(t, opts)
	assert.NoError(t, err, "examples/baseline-regulated: terraform init failed")

	_, err = terraform.ValidateE(t, opts)
	assert.NoError(t, err, "examples/baseline-regulated: terraform validate failed")
}
