/* Go IPP - IPP core protocol implementation in pure Go
 *
 * Copyright (C) 2020 and up by Alexander Pevzner (pzz@apevzner.com)
 * See LICENSE for license terms and conditions
 *
 * IPP Tags tests
 */

package goipp

import (
	"fmt"
	"math"
	"testing"
)

// TestTagIsDelimiter tests Tag.IsDelimiter function
func TestTagIsDelimiter(t *testing.T) {
	type testData struct {
		t      Tag
		answer bool
	}

	tests := []testData{
		{TagZero, true},
		{TagOperationGroup, true},
		{TagJobGroup, true},
		{TagEnd, true},
		{TagFuture15Group, true},
		{TagUnsupportedValue, false},
		{TagUnknown, false},
		{TagInteger, false},
		{TagBeginCollection, false},
		{TagEndCollection, false},
		{TagExtension, false},
	}

	for _, test := range tests {
		answer := test.t.IsDelimiter()
		if answer != test.answer {
			t.Errorf("testing Tag.IsDelimiter:\n"+
				"tag:      %s (0x%.2x)\n"+
				"expected: %v\n"+
				"present:  %v\n",
				test.t, uint32(test.t), test.answer, answer,
			)
		}
	}
}

// TestTagIsGroup tests Tag.IsGroup function
func TestTagIsGroup(t *testing.T) {
	type testData struct {
		t      Tag
		answer bool
	}

	tests := []testData{
		{TagZero, false},
		{TagOperationGroup, true},
		{TagJobGroup, true},
		{TagEnd, false},
		{TagPrinterGroup, true},
		{TagUnsupportedGroup, true},
		{TagSubscriptionGroup, true},
		{TagEventNotificationGroup, true},
		{TagResourceGroup, true},
		{TagDocumentGroup, true},
		{TagSystemGroup, true},
		{TagFuture11Group, true},
		{TagFuture12Group, true},
		{TagFuture13Group, true},
		{TagFuture14Group, true},
		{TagFuture15Group, true},
		{TagInteger, false},
	}

	for _, test := range tests {
		answer := test.t.IsGroup()
		if answer != test.answer {
			t.Errorf("testing Tag.IsGroup:\n"+
				"tag:      %s (0x%.2x)\n"+
				"expected: %v\n"+
				"present:  %v\n",
				test.t, uint32(test.t), test.answer, answer,
			)
		}
	}
}

// TestTagType tests Tag.Type function
func TestTagType(t *testing.T) {
	type testData struct {
		t      Tag
		answer Type
	}

	tests := []testData{
		{TagZero, TypeInvalid},
		{TagInteger, TypeInteger},
		{TagEnum, TypeInteger},
		{TagBoolean, TypeBoolean},
		{TagUnsupportedValue, TypeVoid},
		{TagDefault, TypeVoid},
		{TagUnknown, TypeVoid},
		{TagNotSettable, TypeVoid},
		{TagNoValue, TypeVoid},
		{TagDeleteAttr, TypeVoid},
		{TagAdminDefine, TypeVoid},
		{TagText, TypeString},
		{TagName, TypeString},
		{TagReservedString, TypeString},
		{TagKeyword, TypeString},
		{TagURI, TypeString},
		{TagURIScheme, TypeString},
		{TagCharset, TypeString},
		{TagLanguage, TypeString},
		{TagMimeType, TypeString},
		{TagMemberName, TypeString},
		{TagDateTime, TypeDateTime},
		{TagResolution, TypeResolution},
		{TagRange, TypeRange},
		{TagTextLang, TypeTextWithLang},
		{TagNameLang, TypeTextWithLang},
		{TagBeginCollection, TypeCollection},
		{TagEndCollection, TypeVoid},
		{TagExtension, TypeBinary},
		{0x1234, TypeBinary},
	}

	for _, test := range tests {
		answer := test.t.Type()
		if answer != test.answer {
			t.Errorf("testing Tag.Type:\n"+
				"tag:      %s (0x%.2x)\n"+
				"expected: %v\n"+
				"present:  %v\n",
				test.t, uint32(test.t), test.answer, answer,
			)
		}
	}
}

// TestTagString tests Tag.String function
func TestTagString(t *testing.T) {
	type testData struct {
		t      Tag
		answer string
	}

	tests := []testData{
		{TagZero, "zero"},
		{TagUnsupportedValue, "unsupported"},
		{-1, "0xffffffff"},
		{0xff, "0xff"},
		{0x1234, "0x00001234"},
	}

	for _, test := range tests {
		answer := test.t.String()
		if answer != test.answer {
			t.Errorf("testing Tag.String:\n"+
				"tag:      %s (0x%.2x)\n"+
				"expected: %v\n"+
				"present:  %v\n",
				test.t, uint32(test.t), test.answer, answer,
			)
		}
	}
}

// TestTagGoString tests Tag.GoString function
func TestTagGoString(t *testing.T) {
	type testData struct {
		t      Tag
		answer string
	}

	tests := []testData{
		{TagZero, "goipp.TagZero"},
		{TagUnsupportedValue, "goipp.TagUnsupportedValue"},
		{-1, "goipp.Tag(0xffffffff)"},
		{0xff, "goipp.Tag(0xff)"},
		{0x1234, "goipp.Tag(0x00001234)"},
	}

	for _, test := range tests {
		answer := fmt.Sprintf("%#v", test.t)
		if answer != test.answer {
			t.Errorf("testing Tag.GoString:\n"+
				"tag:      %s (0x%.2x)\n"+
				"expected: %v\n"+
				"present:  %v\n",
				test.t, uint32(test.t), test.answer, answer,
			)
		}
	}
}

// TestTagLimits tests Tag.Limits function
func TestTagLimits(t *testing.T) {
	type testData struct {
		tag      Tag
		min, max int32
	}

	tests := []testData{
		{TagZero, math.MinInt32, math.MaxInt32},
		{TagOperationGroup, math.MinInt32, math.MaxInt32},
		{TagJobGroup, math.MinInt32, math.MaxInt32},
		{TagEnd, math.MinInt32, math.MaxInt32},

		{TagUnsupportedValue, math.MinInt32, math.MaxInt32},
		{TagDefault, math.MinInt32, math.MaxInt32},
		{TagUnknown, math.MinInt32, math.MaxInt32},
		{TagNoValue, math.MinInt32, math.MaxInt32},
		{TagNotSettable, math.MinInt32, math.MaxInt32},
		{TagDeleteAttr, math.MinInt32, math.MaxInt32},
		{TagAdminDefine, math.MinInt32, math.MaxInt32},

		{TagBeginCollection, math.MinInt32, math.MaxInt32},
		{TagBoolean, math.MinInt32, math.MaxInt32},
		{TagCharset, 0, 63},
		{TagDateTime, math.MinInt32, math.MaxInt32},
		{TagEndCollection, math.MinInt32, math.MaxInt32},
		{TagEnum, 1, math.MaxInt32},
		{TagInteger, math.MinInt32, math.MaxInt32},
		{TagKeyword, 1, 255},
		{TagLanguage, 0, 63},
		{TagMimeType, 0, 255},
		{TagName, 0, 255},
		{TagNameLang, 0, 255},
		{TagRange, math.MinInt32, math.MaxInt32},
		{TagReservedString, math.MinInt32, math.MaxInt32},
		{TagResolution, math.MinInt32, math.MaxInt32},
		{TagString, 0, 1023},
		{TagText, 0, 1023},
		{TagTextLang, 0, 1023},
		{TagURI, 0, 1023},
		{TagURIScheme, 0, 63},
	}

	for _, test := range tests {
		min, max := test.tag.Limits()
		if min != test.min || max != test.max {
			t.Errorf("testing Tag.Limits:\n"+
				"tag:              %#v\n"+
				"min/max expected: %d/%d\n"+
				"min/max present:  %d/%d\n",
				test.tag, test.min, test.max, min, max)
		}
	}
}
