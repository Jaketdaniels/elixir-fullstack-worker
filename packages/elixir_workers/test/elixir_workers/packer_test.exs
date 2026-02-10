defmodule ElixirWorkers.PackerTest do
  use ExUnit.Case, async: true

  alias ElixirWorkers.Packer

  describe "parse_iff_chunks/1" do
    test "parses a valid BEAM file" do
      # Create a minimal beam by compiling a module
      {:module, TestMod, beam, _} = defmodule(TestMod, do: nil)
      chunks = Packer.parse_iff_chunks(beam)
      assert is_list(chunks)
      assert length(chunks) > 0
      chunk_names = Enum.map(chunks, fn {name, _} -> name end)
      assert "AtU8" in chunk_names or "Atom" in chunk_names
      assert "Code" in chunk_names
    after
      :code.purge(TestMod)
      :code.delete(TestMod)
    end

    test "raises on invalid data" do
      assert_raise RuntimeError, ~r/Not a valid BEAM/, fn ->
        Packer.parse_iff_chunks("not a beam file")
      end
    end
  end

  describe "process_beam/1" do
    test "produces valid IFF output" do
      {:module, TestMod2, beam, _} = defmodule(TestMod2, do: nil)
      processed = Packer.process_beam(beam)
      assert is_binary(processed)
      assert byte_size(processed) > 0
      <<"FOR1", _size::32-big, "BEAM", _rest::binary>> = processed
    after
      :code.purge(TestMod2)
      :code.delete(TestMod2)
    end

    test "strips unnecessary chunks" do
      {:module, TestMod3, beam, _} = defmodule(TestMod3, do: nil)
      original_chunks = Packer.parse_iff_chunks(beam) |> Enum.map(&elem(&1, 0))
      processed = Packer.process_beam(beam)
      processed_chunks = Packer.parse_iff_chunks(processed) |> Enum.map(&elem(&1, 0))

      # Processed should not have Dbgi, Docs, etc.
      refute "Dbgi" in processed_chunks
      refute "Docs" in processed_chunks

      # But should keep essential chunks
      assert "Code" in processed_chunks

      # Processed should have fewer or equal chunks
      assert length(processed_chunks) <= length(original_chunks)
    after
      :code.purge(TestMod3)
      :code.delete(TestMod3)
    end
  end

  describe "imported_modules/1" do
    test "extracts imports from a beam binary" do
      {:module, TestMod4, beam, _} =
        defmodule TestMod4 do
          def hello, do: Enum.map([1, 2], &(&1 + 1))
        end

      imports = Packer.imported_modules(beam)
      assert is_struct(imports, MapSet)
      # Should contain Enum since we call Enum.map
      assert "Elixir.Enum" in imports
    after
      :code.purge(TestMod4)
      :code.delete(TestMod4)
    end

    test "returns empty set for invalid binary" do
      assert Packer.imported_modules("not a beam") == MapSet.new()
    end
  end

  describe "create_avm/3" do
    test "creates a valid .avm archive" do
      # Compile two test modules
      {:module, StartMod, start_beam, _} = defmodule(StartMod, do: nil)
      {:module, HelperMod, helper_beam, _} = defmodule(HelperMod, do: nil)

      # Write beams to temp dir
      tmp_dir = Path.join(System.tmp_dir!(), "packer_test_#{:rand.uniform(1_000_000)}")
      File.mkdir_p!(tmp_dir)
      File.write!(Path.join(tmp_dir, "Elixir.StartMod.beam"), start_beam)
      File.write!(Path.join(tmp_dir, "Elixir.HelperMod.beam"), helper_beam)

      output = Path.join(tmp_dir, "test.avm")
      {size, count} = Packer.create_avm(output, "Elixir.StartMod.beam", tmp_dir)

      assert size > 0
      assert count == 2
      assert File.exists?(output)

      # Verify AVM header
      content = File.read!(output)
      assert String.starts_with?(content, "#!/usr/bin/env AtomVM\n")

      File.rm_rf!(tmp_dir)
    after
      :code.purge(StartMod)
      :code.delete(StartMod)
      :code.purge(HelperMod)
      :code.delete(HelperMod)
    end

    test "raises when startup module not found" do
      tmp_dir = Path.join(System.tmp_dir!(), "packer_test_missing_#{:rand.uniform(1_000_000)}")
      File.mkdir_p!(tmp_dir)

      {:module, DummyMod, dummy_beam, _} = defmodule(DummyMod, do: nil)
      File.write!(Path.join(tmp_dir, "Elixir.DummyMod.beam"), dummy_beam)

      assert_raise RuntimeError, ~r/Startup module.*not found/, fn ->
        Packer.create_avm(Path.join(tmp_dir, "test.avm"), "Elixir.Missing.beam", tmp_dir)
      end

      File.rm_rf!(tmp_dir)
    after
      :code.purge(DummyMod)
      :code.delete(DummyMod)
    end
  end
end
