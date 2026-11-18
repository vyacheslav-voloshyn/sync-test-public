// The public build: the core and the public features only.
package main

import (
	"fmt"

	"github.com/vyacheslav-voloshyn/sync-test-public/core"
	_ "github.com/vyacheslav-voloshyn/sync-test-public/core/fractal"
)

func main() {
	for _, f := range core.Features() {
		fmt.Printf("%-8s %s\n", f.Name, f.Describe())
	}
}
