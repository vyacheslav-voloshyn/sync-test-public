// Package core stands in for the public product. A feature registers itself
// from its package's init, so a build decides which features exist by the
// packages it imports. A private build adds features without touching this tree.
package core

type Feature struct {
	Name     string
	Describe func() string
}

var features []Feature

func Register(f Feature) { features = append(features, f) }

func Features() []Feature { return features }
