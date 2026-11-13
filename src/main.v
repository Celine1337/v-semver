module main

import os

// v-semver - SemVer 2.0.0 compare / bump / validate. Pure V, no dependencies.
// Precedence rules per https://semver.org/spec/v2.0.0.html:
//   - major.minor.patch compared numerically
//   - a version WITH prerelease < the same version without
//   - prerelease identifiers: numeric compared numerically, others lexically
//     (ASCII), numeric < non-numeric, fewer fields < more when all equal
//   - build metadata (+...) is ignored for precedence
// Numeric components are kept as validated decimal strings so comparison
// works for arbitrarily large numbers without integer overflow.

struct Version {
	nums []string // major, minor, patch: digits only, no leading zeros
	pre  []string // prerelease identifiers; empty means a release version
}

fn is_digit(c u8) bool {
	return c >= u8(48) && c <= u8(57)
}

fn is_num_str(s string) bool {
	if s.len == 0 {
		return false
	}
	for i := 0; i < s.len; i++ {
		if !is_digit(s[i]) {
			return false
		}
	}
	return true
}

// core numeric identifier: digits only, no leading zeros unless it is "0"
fn valid_num_id(s string) bool {
	if !is_num_str(s) {
		return false
	}
	return s.len == 1 || s[0] != u8(48)
}

// prerelease / build identifier characters: [0-9A-Za-z-], non-empty
fn valid_id_chars(s string) bool {
	if s.len == 0 {
		return false
	}
	for i := 0; i < s.len; i++ {
		c := s[i]
		if !(is_digit(c) || (c >= u8(65) && c <= u8(90)) || (c >= u8(97) && c <= u8(122))
			|| c == u8(45)) {
			return false
		}
	}
	return true
}

fn parse_version(s string) !Version {
	if s.len == 0 {
		return error('empty version')
	}
	mut core_pre := s
	// strip and validate build metadata (ignored for precedence)
	if s.contains('+') {
		parts := s.split('+')
		if parts.len != 2 {
			return error('multiple build separators')
		}
		for id in parts[1].split('.') {
			if !valid_id_chars(id) {
				return error('bad build metadata')
			}
		}
		core_pre = parts[0]
	}
	mut core := core_pre
	mut pre := []string{}
	// strip and validate prerelease (first '-' separates; ids may contain '-')
	if core_pre.contains('-') {
		parts := core_pre.split('-')
		core = parts[0]
		pre_str := parts[1..].join('-')
		if pre_str.len == 0 {
			return error('empty prerelease')
		}
		for id in pre_str.split('.') {
			if !valid_id_chars(id) {
				return error('bad prerelease identifier')
			}
			if is_num_str(id) && id.len > 1 && id[0] == u8(48) {
				return error('numeric prerelease identifier with leading zero')
			}
		}
		pre = pre_str.split('.')
	}
	nums := core.split('.')
	if nums.len != 3 {
		return error('expected major.minor.patch')
	}
	for n in nums {
		if !valid_num_id(n) {
			return error('bad numeric component')
		}
	}
	return Version{
		nums: nums
		pre:  pre
	}
}

// compare two validated decimal strings of arbitrary length
fn cmp_num_str(a string, b string) int {
	if a.len != b.len {
		return if a.len < b.len { -1 } else { 1 }
	}
	if a == b {
		return 0
	}
	return if a < b { -1 } else { 1 }
}

fn compare(a Version, b Version) int {
	for i := 0; i < 3; i++ {
		c := cmp_num_str(a.nums[i], b.nums[i])
		if c != 0 {
			return c
		}
	}
	if a.pre.len == 0 && b.pre.len == 0 {
		return 0
	}
	if a.pre.len == 0 {
		return 1 // release > prerelease
	}
	if b.pre.len == 0 {
		return -1
	}
	n := if a.pre.len < b.pre.len { a.pre.len } else { b.pre.len }
	for i := 0; i < n; i++ {
		x := a.pre[i]
		y := b.pre[i]
		xn := is_num_str(x)
		yn := is_num_str(y)
		if xn && yn {
			c := cmp_num_str(x, y)
			if c != 0 {
				return c
			}
		} else if xn {
			return -1 // numeric < non-numeric
		} else if yn {
			return 1
		} else if x != y {
			return if x < y { -1 } else { 1 }
		}
	}
	if a.pre.len == b.pre.len {
		return 0
	}
	return if a.pre.len < b.pre.len { -1 } else { 1 }
}

fn bump(v Version, part string) !string {
	if v.nums[0].len > 18 || v.nums[1].len > 18 || v.nums[2].len > 18 {
		return error('version component too large to bump')
	}
	mut m := v.nums[0].int()
	mut n := v.nums[1].int()
	mut p := v.nums[2].int()
	match part {
		'major' {
			m++
			n = 0
			p = 0
		}
		'minor' {
			n++
			p = 0
		}
		'patch' {
			p++
		}
		else {
			return error('unknown bump part')
		}
	}
	return '${m}.${n}.${p}'
}

fn usage() {
	eprintln('usage:')
	eprintln('  v-semver compare <A> <B>              print -1, 0 or 1 (A<B, A==B, A>B)')
	eprintln('  v-semver bump <ver> <major|minor|patch>  print bumped version')
	eprintln('  v-semver valid <ver>                  print valid/invalid (exit 0/1)')
	exit(2)
}

fn main() {
	args := os.args
	if args.len < 2 {
		usage()
	}
	match args[1] {
		'compare' {
			if args.len != 4 {
				usage()
			}
			a := parse_version(args[2]) or {
				eprintln('v-semver: invalid version "${args[2]}": ${err}')
				exit(1)
			}
			b := parse_version(args[3]) or {
				eprintln('v-semver: invalid version "${args[3]}": ${err}')
				exit(1)
			}
			println(compare(a, b))
		}
		'bump' {
			if args.len != 4 {
				usage()
			}
			if args[3] !in ['major', 'minor', 'patch'] {
				usage()
			}
			v := parse_version(args[2]) or {
				eprintln('v-semver: invalid version "${args[2]}": ${err}')
				exit(1)
			}
			out := bump(v, args[3]) or {
				eprintln('v-semver: ${err}')
				exit(1)
			}
			println(out)
		}
		'valid' {
			if args.len != 3 {
				usage()
			}
			parse_version(args[2]) or {
				println('invalid')
				exit(1)
			}
			println('valid')
		}
		else {
			usage()
		}
	}
}