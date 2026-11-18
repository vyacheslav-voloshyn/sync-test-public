// Package fractal stands in for the public fractal module.
package fractal

import (
	"strings"

	"github.com/vyacheslav-voloshyn/sync-test-public/core"
)

// Capabilities lists what a node reports to the node above it. A private
// build may append to it from its own package's init.
var Capabilities = []string{"jobs", "files", "tool-count"}

func init() {
	core.Register(core.Feature{Name: "fractal", Describe: func() string {
		return "fractal node, capabilities: " + strings.Join(Capabilities, ", ")
	}})
}
