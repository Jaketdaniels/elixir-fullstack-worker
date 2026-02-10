defmodule ElixirWorkers.HTMLTest do
  use ExUnit.Case, async: true

  alias ElixirWorkers.HTML

  describe "escape/1" do
    test "escapes ampersand" do
      assert HTML.escape("a&b") == "a&amp;b"
    end

    test "escapes angle brackets" do
      assert HTML.escape("<div>") == "&lt;div&gt;"
    end

    test "escapes quotes" do
      assert HTML.escape(~s(say "hi")) == "say &quot;hi&quot;"
    end

    test "escapes single quotes" do
      assert HTML.escape("it's") == "it&#39;s"
    end

    test "passes through safe text" do
      assert HTML.escape("hello world") == "hello world"
    end

    test "escapes all special characters together" do
      assert HTML.escape("<script>alert('xss')</script>") ==
               "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
    end

    test "handles empty string" do
      assert HTML.escape("") == ""
    end

    test "escapes non-string values via to_string" do
      assert HTML.escape(42) == "42"
    end
  end

  describe "tag/3" do
    test "builds tag with no attributes" do
      assert HTML.tag("div", %{}, "hello") == "<div>hello</div>"
    end

    test "builds tag with attributes" do
      result = HTML.tag("a", %{"href" => "/home"}, "Home")
      assert result =~ "<a"
      assert result =~ ~s(href="/home")
      assert result =~ ">Home</a>"
    end

    test "escapes attribute values" do
      result = HTML.tag("div", %{"title" => "say \"hi\""}, "content")
      assert result =~ "&quot;"
    end
  end

  describe "tag/2" do
    test "builds tag with content only" do
      assert HTML.tag("p", "hello") == "<p>hello</p>"
    end
  end

  describe "void_tag/2" do
    test "builds self-closing tag" do
      result = HTML.void_tag("input", %{"type" => "text"})
      assert result =~ "<input"
      assert result =~ ~s(type="text")
      assert result =~ "/>"
    end
  end

  describe "void_tag/1" do
    test "builds self-closing tag without attributes" do
      assert HTML.void_tag("br") == "<br/>"
    end
  end

  describe "each/2" do
    test "renders list items" do
      result = HTML.each(["a", "b"], fn item -> "<li>#{item}</li>" end)
      assert result == "<li>a</li><li>b</li>"
    end

    test "handles empty list" do
      assert HTML.each([], fn _ -> "x" end) == ""
    end
  end
end
