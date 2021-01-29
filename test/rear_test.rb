#!/usr/bin/env rspec

require_relative "./test_helper"

Yast.import "Rear"

describe Yast::Rear do
  describe "#RearListToYCPList" do
    it "correctly splits and parses a given input list" do
      ycplist = subject.RearListToYCPList("()")
      expect(ycplist).to eq([])

      ycplist = subject.RearListToYCPList("(a)")
      expect(ycplist).to eq(["a"])

      ycplist = subject.RearListToYCPList("(a b  c)")
      expect(ycplist).to eq(["a", "b", "c"])

      ycplist = subject.RearListToYCPList("(a\\ b c)")
      expect(ycplist).to eq(["a b", "c"])

      ycplist = subject.RearListToYCPList("(a\\ \\ \\ b c)")
      expect(ycplist).to eq(["a   b", "c"])

      ycplist = subject.RearListToYCPList("(a* b)")
      expect(ycplist).to eq(["a*", "b"])

      ycplist = subject.RearListToYCPList("('a' b)")
      expect(ycplist).to eq(["'a'", "b"])
    end
  end

  describe "#YCPListToRearList" do
    it "correctly transforms a given list for output" do
      rearlist = subject.YCPListToRearList([])
      expect(rearlist).to eq(("()"))

      rearlist = subject.YCPListToRearList(["a"])
      expect(rearlist).to eq("(a)")

      rearlist = subject.YCPListToRearList(["a", "b", "c"])
      expect(rearlist).to eq("(a b c)")

      rearlist = subject.YCPListToRearList(["a b", "c"])
      expect(rearlist).to eq("(a\\ b c)")

      rearlist = subject.YCPListToRearList(["a   b", "c"])
      expect(rearlist).to eq("(a\\ \\ \\ b c)")

      rearlist = subject.YCPListToRearList(["a*", "b"])
      expect(rearlist).to eq("(a* b)")

      rearlist = subject.YCPListToRearList(["'a'", "b"])
      expect(rearlist).to eq("('a' b)")
    end
  end

  describe "#RearQuotedListToYCPList" do
    it "correctly splits and parses a given input list" do
      ycplist = subject.RearQuotedListToYCPList("()")
      expect(ycplist).to eq([])

      ycplist = subject.RearQuotedListToYCPList("(a)")
      expect(ycplist).to eq(["a"])

      ycplist = subject.RearQuotedListToYCPList("(a b  c)")
      expect(ycplist).to eq(["a", "b", "c"])

      ycplist = subject.RearQuotedListToYCPList("(a\\ b c)")
      expect(ycplist).to eq(["a b", "c"])

      ycplist = subject.RearQuotedListToYCPList("(a\\ \\ \\ b c)")
      expect(ycplist).to eq(["a   b", "c"])

      ycplist = subject.RearQuotedListToYCPList("(a* b)")
      expect(ycplist).to eq(["a*", "b"])

      ycplist = subject.RearQuotedListToYCPList("('a' b)")
      expect(ycplist).to eq(["a", "b"])

      ycplist = subject.RearQuotedListToYCPList("('a'\\''b' c)")
      expect(ycplist).to eq(["a'b", "c"])

      ycplist = subject.RearQuotedListToYCPList("('' a)")
      expect(ycplist).to eq(["a"])
    end
  end

  describe "#YCPListToRearQuotedList" do
    it "correctly transforms a given list for output" do
      rearlist = subject.YCPListToRearQuotedList([])
      expect(rearlist).to eq("()")

      rearlist = subject.YCPListToRearQuotedList(["a"])
      expect(rearlist).to eq("('a')")

      rearlist = subject.YCPListToRearQuotedList(["a", "b", "c"])
      expect(rearlist).to eq("('a' 'b' 'c')")

      rearlist = subject.YCPListToRearQuotedList(["a b", "c"])
      expect(rearlist).to eq("('a b' 'c')")

      rearlist = subject.YCPListToRearQuotedList(["a   b", "c"])
      expect(rearlist).to eq("('a   b' 'c')")

      rearlist = subject.YCPListToRearQuotedList(["a*", "b"])
      expect(rearlist).to eq("('a*' 'b')")

      rearlist = subject.YCPListToRearQuotedList(["a", "b"])
      expect(rearlist).to eq("('a' 'b')")

      rearlist = subject.YCPListToRearQuotedList(["a'b", "c"])
      expect(rearlist).to eq("('a'\\''b' 'c')")

      rearlist = subject.YCPListToRearQuotedList([""])
      expect(rearlist).to eq("('')")
    end
  end
end
