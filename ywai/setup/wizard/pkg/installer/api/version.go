package api

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

// Version represents a semantic version
type Version struct {
	Major int
	Minor int
	Patch int
}

// ParseVersion parses a version string into Version struct
func ParseVersion(version string) (Version, error) {
	// Remove 'v' prefix if present
	version = strings.TrimPrefix(version, "v")
	
	// Extract version numbers using regex
	re := regexp.MustCompile(`^(\d+)\.(\d+)\.(\d+)`)
	matches := re.FindStringSubmatch(version)
	if len(matches) != 4 {
		return Version{}, fmt.Errorf("invalid version format: %s", version)
	}
	
	major, err := strconv.Atoi(matches[1])
	if err != nil {
		return Version{}, fmt.Errorf("invalid major version: %s", matches[1])
	}
	
	minor, err := strconv.Atoi(matches[2])
	if err != nil {
		return Version{}, fmt.Errorf("invalid minor version: %s", matches[2])
	}
	
	patch, err := strconv.Atoi(matches[3])
	if err != nil {
		return Version{}, fmt.Errorf("invalid patch version: %s", matches[3])
	}
	
	return Version{
		Major: major,
		Minor: minor,
		Patch: patch,
	}, nil
}

// Compare compares two versions
// Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
func (v Version) Compare(other Version) int {
	if v.Major != other.Major {
		if v.Major < other.Major {
			return -1
		}
		return 1
	}
	
	if v.Minor != other.Minor {
		if v.Minor < other.Minor {
			return -1
		}
		return 1
	}
	
	if v.Patch != other.Patch {
		if v.Patch < other.Patch {
			return -1
		}
		return 1
	}
	
	return 0
}

// String returns the string representation of the version
func (v Version) String() string {
	return fmt.Sprintf("v%d.%d.%d", v.Major, v.Minor, v.Patch)
}

// IsNewerThan checks if this version is newer than the other
func (v Version) IsNewerThan(other Version) bool {
	return v.Compare(other) > 0
}

// IsOlderThan checks if this version is older than the other
func (v Version) IsOlderThan(other Version) bool {
	return v.Compare(other) < 0
}

// IsEqual checks if this version is equal to the other
func (v Version) IsEqual(other Version) bool {
	return v.Compare(other) == 0
}

// CompareVersions compares two version strings
func CompareVersions(v1, v2 string) (int, error) {
	version1, err := ParseVersion(v1)
	if err != nil {
		return 0, fmt.Errorf("failed to parse version1: %w", err)
	}
	
	version2, err := ParseVersion(v2)
	if err != nil {
		return 0, fmt.Errorf("failed to parse version2: %w", err)
	}
	
	return version1.Compare(version2), nil
}

// IsNewerVersion checks if v1 is newer than v2
func IsNewerVersion(v1, v2 string) (bool, error) {
	cmp, err := CompareVersions(v1, v2)
	if err != nil {
		return false, err
	}
	return cmp > 0, nil
}

// IsOlderVersion checks if v1 is older than v2
func IsOlderVersion(v1, v2 string) (bool, error) {
	cmp, err := CompareVersions(v1, v2)
	if err != nil {
		return false, err
	}
	return cmp < 0, nil
}

// AreVersionsEqual checks if v1 and v2 are equal
func AreVersionsEqual(v1, v2 string) (bool, error) {
	cmp, err := CompareVersions(v1, v2)
	if err != nil {
		return false, err
	}
	return cmp == 0, nil
}
