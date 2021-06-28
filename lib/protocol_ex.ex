defmodule ProtocolEx do
  @moduledoc """
  Matcher protocol control module
  """

  @no_match :__@@NO_MATCH@@__

  defmodule InvalidProtocolSpecification do
    @moduledoc """
    This is raised when a protocol definition is invalid.

    If a new feature is wanted in the protocol definition, please raise an issue or submit a PR.
    """
    defexception [ast: nil]
    def message(exc), do: "Unhandled specification node:  #{inspect exc.ast}"
  end

  defmodule MissingAsInArgs do
    @moduledoc """
    This is raised when an `as` name is specified but is missing from a function argument list.
    """
    defexception [as: nil, ast: nil]
    def message(exc), do: "Missing required name #{exc.as} in:  #{inspect exc.ast}"
  end

  defmodule DuplicateSpecification do
    @moduledoc """
    Only one implementation for a given callback per implementaiton is allowed at this time.
    """
    defexception [name: nil, arity: 0]
    def message(exc) do
      if exc.arity === -1 do
        "Cannot specify both a 0-arity and 1-arity version of the same function:  #{inspect exc.name}"
      else
        "Duplicate specification node:  #{inspect exc.name}/#{inspect exc.arity}"
      end
    end
  end

  defmodule UnimplementedProtocolEx do
    @moduledoc """
    Somehow a given implementation was consolidated without actually having a required callback specified.
    """
    defexception [proto: nil, name: nil, arity: 0, value: nil]
    def message(exc), do: "Unimplemented Protocol of `#{exc.proto}` at #{inspect exc.name}/#{inspect exc.arity} with arguments: #{inspect exc.value}"
  end

  defmodule MissingRequiredProtocolDefinition do
    @moduledoc """
    The given implementation is missing a required callback from the protocol.
    """
    defexception [proto: nil, impl: nil, name: nil, arity: -1]
    def message(exc) do
      impl = String.replace_prefix(to_string(exc.impl), to_string(exc.proto)<>".", "")
      "On Protocol `#{exc.proto}` missing a required protocol callback on `#{impl}` of:  #{exc.name}/#{exc.arity}"
    end
  end

  defmodule ProtocolExTestFailure do
    @moduledoc """
    A failed test and information about the error condition
    """
    defexception [proto: nil, type: nil, name: nil, meta: nil, value: nil]
    def message(exc) do
      location = inspect(exc.meta)
      "\nOn Protocol `#{exc.proto}`\n\twith type of `#{exc.type}`,\n\tfailed test `#{exc.name}`/#{location}\n\twith error value of: #{inspect exc.value}\n\n"
    end
  end


  defmodule Spec do
    @moduledoc false
    defstruct [
      callbacks: [],
      as: nil,
      location: [],
      docs: %{},
      head_asts: [],
      cache: %{}, # Used only at compile-time, cleared before saving
    ]
  end

  def clean_spec(%Spec{} = spec) do
    %{spec|
      head_asts: [],
      cache: %{},
    }
  end


  @desc_name :"$ProtocolEx_description$"
  @desc_attr :protocol_ex_desc


  @doc """
  Define a protocol behaviour.
  """
  defmacro defprotocolEx(name, opts \\ [], [do: body]) do
    # body = globalize_ast(body, __CALLER__, __MODULE__.ProtoScope)
    parsed_name = get_atom_name(name, __CALLER__)
    name = get_atom_name(name)
    desc_name = get_atom_name_with(name, @desc_name) |> get_atom_name(__CALLER__)
    as =
      case opts[:as] do
        nil -> nil
        {name, _, scope} when is_atom(name) and is_atom(scope) -> name
      end
    body =
      case body do
        {:__block__, _meta, _lines} = ast -> ast
        line -> {:__block__, [], [line]}
      end
      |> case do {:__block__, meta, lines} ->
          lines = Enum.map(lines, fn
            {type, _, _} = ast when type in [:def, :defp, :defmacro, :defmacrop, :@] -> ast
            ast -> Macro.expand(ast, __CALLER__)
          end)
          {:__block__, meta, lines}
      end
    spec = decompose_spec(__CALLER__, as, body)
    spec = verify_valid_spec(spec)
    desc_body =
      quote do
        @moduledoc false

        Module.register_attribute(__MODULE__, unquote(@desc_attr), persist: true)
        @protocol_ex_desc unquote(parsed_name)
        def spec, do: unquote(Macro.escape(spec))
      end
    # desc_body |> Macro.to_string() |> Code.format_string!() |> IO.puts()
    Module.create(desc_name, desc_body, __CALLER__) # Macro.Env.location(__CALLER__))
    consolidate(parsed_name, [impls: []]) # A temporary hoister
    if parsed_name == name do
      generate_alias_usage(body, __CALLER__)
    else
      [
        quote(generated: true, do: alias(unquote(parsed_name), as: unquote(name))),
        quote(generated: true, do: _ = unquote(name))
      | generate_alias_usage(body, __CALLER__)
      ]
    end
  end

  defmacro defprotocol_ex(name, opts \\ [], bodies) do
    quote do
      ProtocolEx.defprotocolEx(unquote(name), unquote(opts), unquote(bodies))
    end
  end



  @doc """
  Implement a protocol based on a matcher specification
  """
  defmacro defimplEx(impl_name, matcher, [{:for, for_name} | opts], [do: body]) do
    name = globalize_ast(for_name, __CALLER__, __MODULE__.Unused)
    name = get_atom_name(name)
    name = __CALLER__.aliases[name] || name
    desc_name = get_desc_name(name)
    impl_name = get_atom_name(impl_name)
    # body = globalize_ast(body, __CALLER__, __MODULE__.ImplScope)
    gmatcher = globalize_ast(matcher, __CALLER__, __MODULE__.ImplScope)
    [ quote do
        require unquote(desc_name)
        ProtocolEx.defimplEx_do(unquote(Macro.escape(impl_name)), unquote(Macro.escape(gmatcher)), [for: unquote(Macro.escape(name))], [do: unquote(Macro.escape(body))], unquote(opts), unquote({:__ENV__, [], nil}))
      end
    | generate_alias_usage(matcher, __CALLER__)
    ++ generate_alias_usage(body, __CALLER__)
    ++ generate_alias_usage(for_name, __CALLER__)
    ] # |>case do ast -> IO.puts(Code.format_string!(Macro.to_string(ast))); ast end
  end

  defmacro defimpl_ex(impl_name, matcher, opts, bodies) do
    quote do
      ProtocolEx.defimplEx(unquote(impl_name), unquote(matcher), unquote(opts), unquote(bodies))
    end
  end

  @doc false
  def defimplEx_do(impl_name, matcher, [for: name], [do: body], opts, caller_env) do
    desc_name = get_desc_name(name)
    impl_name = get_atom_name(impl_name, caller_env)
    impl_name = get_impl_name(name, impl_name)
    impl_name = get_atom_name(impl_name, caller_env)
    spec = desc_name.spec()

    test_asts = gen_impl_test_asts(spec)

    impl_quoted = {:__block__, [],
      [ if spec.location[:file] in [nil, "", ''] do
          :no_file_resource
        else
          quote do
            # @external_resource unquote(spec.location[:file])
            require unquote(desc_name)
          end
        end,
        quote do
          def __matcher__, do: [unquote(Macro.escape(matcher))]
          def __spec__, do: unquote(desc_name).spec()
          Module.register_attribute(__MODULE__, :protocol_ex, persist: true)
          @protocol_ex unquote(name)
          Module.register_attribute(__MODULE__, :priority, persist: true)
        end
      ] ++
      (case opts[:inline] do
        nil -> [quote do def __inlined__(_), do: nil end]
        # :all -> quote do def __inlined__(_), do: true end
        funs when is_list(funs) ->
          funs
          |> Enum.map(fn {fun, arity} ->
            Macro.prewalk(body, {[], false}, fn
              ({:def, _, [{^fun, _, bindings}, _]} = ast, {acc, false}) when length(bindings) === arity ->
                {ast, {[ast | acc], false}}
              ({:def, _, [{:when, _, [{^fun, _, bindings}, _]}, _]} = ast, {acc, false}) when length(bindings) === arity ->
                {ast, {[ast | acc], false}}
              ({:@, _, [{:ignore, _, _}]}, {acc, false}) ->
                {nil, {acc, true}}
              (ast, {acc, _ignore_next}) ->
                {ast, {acc, false}}
            end)
            |> case do
              {_body, {ast, _ignore_next}} ->
                quote do def __inlined__({unquote(fun), unquote(arity)}), do: unquote(Macro.escape(ast)) end
            end
          end)
          |> List.wrap()
          |> Enum.reverse([quote do def __inlined__(_), do: nil end])
      end
      |> case do
        old_inlines ->
          Macro.prewalk(body, {%{}, false}, fn
            ({:def, _, [{fun, _, bindings}, _]} = ast, {acc, inline}) when is_list(bindings) ->
              arity = length(bindings)
              if inline or Map.get(acc, {fun, arity}, false) do
                acc = Map.update(acc, {fun, arity}, [ast], &[ast | List.wrap(&1)])
                {ast, {acc, false}}
              else
                {ast, {acc, false}}
              end
            ({:def, _, [{:when, _, [{fun, _, bindings}, _]}, _]} = ast, {acc, inline}) when is_list(bindings)->
              arity = length(bindings)
              if inline or Map.get(acc, {fun, arity}, false) do
                acc = Map.update(acc, {fun, arity}, [ast], &[ast | List.wrap(&1)])
                {ast, {acc, false}}
              else
                {ast, {acc, false}}
              end
            ({:@, _, [{:inline, _, _}]}, {acc, false}) -> {nil, {acc, true}}
            (ast, {acc, _inline_next}) -> {ast, {acc, false}}
          end)
          |> case do
            {body, {asts, _inline_next}} ->
              Enum.map(asts, fn {{fun, arity}, ast} ->
                quote do def __inlined__({unquote(fun), unquote(arity)}), do: unquote(Macro.escape(ast)) end
              end) ++
              old_inlines ++
              List.wrap(body) ++
              test_asts
          end
      end)
    }
    # impl_quoted |> Macro.to_string() |> IO.puts
    if Code.ensure_loaded?(impl_name) do
      :code.purge(impl_name)
    end
    Module.create(impl_name, impl_quoted, caller_env) # Macro.Env.location(caller_env))
    verify_valid_spec_on_module(name, spec, impl_name)
  end



  def consolidate_all(opts \\ []) do
    opts
    |> get_base_paths()
    |> Enum.flat_map(fn path ->
      path
      |> Path.join("*.beam")
      |> Path.wildcard()
    end)
    |> case do beam_paths ->
      beam_paths
      |> Enum.flat_map(fn path -> # Oh what I'd give for a monadic `do` right about now...  >.>
        case :beam_lib.chunks(path |> to_charlist(), [:attributes]) do
          {:ok, {_mod, chunks}} ->
            case get_in(chunks, [:attributes, @desc_attr]) do
              [proto] -> [proto]
              _ -> []
            end
          _err -> []
        end
      end)
      |> case do protocols ->
        beam_paths
        |> Enum.flat_map(fn path ->
          case :beam_lib.chunks(path |> to_charlist(), [:attributes]) do
            {:ok, {mod, chunks}} ->
              attributes = chunks[:attributes]
              case attributes[:protocol_ex] do
                nil -> []
                protos ->
                  protos
                  |> Enum.any?(&Enum.member?(protocols, &1))
                  |> if do
                    priority = hd(attributes[:priority] || [0])
                    data = {mod, priority, protos}
                    [data]
                  else
                    []
                  end
              end
            _err -> []
          end
        end)
        |> case do impls ->
# IO.inspect {:consolidating_all, protocols}
          protocols
          |> Enum.map(fn proto_name ->
            consolidate(proto_name, [impls: impls, output_beam: opts[:output_beam], verbose: opts[:verbose], print_protocol_ex: opts[:print_protocol_ex], protocol_tests: opts[:protocol_tests]])
          end)
        end
      end
    end
  end

  @doc """
  Resolve a protocol into a final ready-to-use-module based on already-compiled names sorted by priority
  """
  def consolidate(proto_name, opts \\ []) do
    impls =
      case opts[:impls] do
        nil ->
          opts
          |> get_base_paths()
          |> Enum.flat_map(fn path ->
            path
            |> Path.join("*.beam")
            |> Path.wildcard()
          end)
          |> Enum.flat_map(fn path ->
            case :beam_lib.chunks(path |> to_charlist(), [:attributes]) do
              {:ok, {mod, chunks}} ->
                attributes = chunks[:attributes]
                case attributes[:protocol_ex] do
                  nil -> []
                  protos ->
                    if Enum.member?(protos, proto_name) do
                      priority = hd(attributes[:priority] || [0])
                      data = {mod, priority, protos}
                      [data]
                    else
                      []
                    end
                end
                _err -> []
            end
          end)
        impls -> Enum.filter(impls, &(Enum.member?(elem(&1, 2), proto_name)))
      end
      |> Enum.sort_by(fn {name, prio, _} -> {prio, to_string(name)} end, &>=/2) # Sort by priority, then by binary name
      |> Enum.map(&elem(&1, 0))

    if :erlang.function_exported(proto_name, :__proto_ex_consolidated__, 0) and
      :erlang.function_exported(proto_name, :__proto_ex_impls__, 0) and
      # proto_name.__proto_ex_consolidated__() and
      proto_name.__proto_ex_impls__() === impls do
      proto_name
    else
# IO.inspect {:consolidate, proto_name, impls, if(:erlang.function_exported(proto_name, :__proto_ex_impls__, 0), do: proto_name.__proto_ex_impls__(), else: :does_not_exist)}
      proto_desc = Module.concat(proto_name, @desc_name)
      spec =
        case proto_desc.spec() do
          %Spec{} = spec -> spec
          err -> throw {:invalid_spec, err}
        end

      Enum.map(List.wrap(spec.cache[:requiring]), fn module ->
        if not Code.ensure_loaded?(module) or
          not :erlang.function_exported(module, :__proto_ex_consolidated__, 0) or
          not module.__proto_ex_consolidated__() do
          consolidate(module, [output_beam: opts[:output_beam]])
        end
      end)

      impl_quoted = {:__block__, [],
        if(spec.docs[:moduledoc], do: spec.docs[:moduledoc], else: [quote(do: @moduledoc "<Undocumented>")]) ++
        Enum.map(impls, &quote(do: require unquote(&1))) ++
        :lists.reverse(spec.head_asts) ++
        [ quote do def __protocol_ex__, do: unquote(Macro.escape(clean_spec(spec))) end,
          quote do def __proto_ex_consolidated__, do: unquote(if(impls === [], do: false, else: true)) end,
          quote do def __proto_ex_impls__, do: unquote(impls) end
        | Enum.flat_map(:lists.reverse(spec.callbacks), &load_abstract_from_impls(spec, proto_name, &1, impls))
        ] ++
        Enum.flat_map(spec.callbacks, &load_test_from_impls(proto_name, &1, impls)) ++
        load_tests_from_impls(spec.callbacks)
      }
      # impl_quoted |> Macro.to_string() |> IO.puts
      if Code.ensure_loaded?(proto_name) do
# IO.inspect {:purging, proto_name}
        :code.purge(proto_name)
      end
      Code.compiler_options(ignore_module_conflict: true)
      if opts[:print_protocol_ex] || System.get_env("PRINT_PROTOCOL_EX") not in [nil, ""] do
        quote do
          defmodule unquote(proto_name) do
            unquote(impl_quoted)
          end
        end
        |> Macro.to_string()
        |> Code.format_string!()
        |> IO.puts()
      end
      #IO.inspect({proto_name, impl_quoted, spec.location}, label: :CONSOLIDATED)
      #impl_quoted |> Macro.to_string() |> Code.format_string!() |> IO.puts()
      {:module, beam_name, beam_data, _exports} = Module.create(proto_name, impl_quoted, spec.location)
      case opts[:output_beam] do
        base_path when is_binary(base_path) -> base_path
        true -> apply(Mix.Project, :build_path, [])
        _ -> nil
      end
      |> case do
        nil -> if(opts[:verbose], do: IO.puts("ProtocolEx inline module: #{beam_name}"))
        base_path ->
          beam_filename = "#{beam_name}.beam"
          glob = Path.join([base_path, "lib", "**", beam_filename])
          path =
            glob
            |> Path.wildcard()
            |> Enum.sort()
            |> case do
              [] -> raise "ProtocolEx consolidation failed: could not find anything for `#{glob}`"
              [path] -> path
              [_|_] = paths -> raise "ProtocolEx consolidation failed: found multiple beam files for `#{glob}` of: #{inspect paths}"
            end
          File.write!(path, beam_data)
          if(opts[:verbose], do: IO.puts("ProtocolEx beam module #{beam_filename} with implementations #{inspect impls}"))
      end
      Code.compiler_options(ignore_module_conflict: false)
      if(opts[:protocol_tests], do: proto_name.__tests_pex__(opts[:protocol_tests]))
      if(false && opts[:verbose], do: IO.puts("ProtocolEx Consolidated: #{proto_name}"))
      proto_name
    end
  end

  @doc """
  Resolve a protocol into a final ready-to-use-module based on implementation names
  """
  defmacro resolveProtocolEx(orig_name, impls, priority_sorted \\ false) when is_list(impls) do
    if(priority_sorted, do: IO.puts("`priority_sorted` is no longer supported, internal sorting is now always used"))
    name = get_atom_name(orig_name)
    name = __CALLER__.aliases[name] || name
    desc_name = get_desc_name(name)
    impls = Enum.map(impls, &get_atom_name/1)
    impls = Enum.map(impls, &get_atom_name_with(name, &1))
    impls = Enum.map(impls, &get_atom_name/1)
    impls = Enum.map(impls, &{&1, &1.module_info()[:attributes][:priority] || 0, [name]})
    #impls = if(priority_sorted, do: Enum.sort_by(impls, &(&1.module_info()[:attributes][:priority] || 0), &>=/2), else: impls)
    requireds = Enum.map([desc_name | impls], fn
      {req, _, _} -> {:require, [], [req]}
      req -> {:require, [], [req]}
    end)
    quote do
      __silence_alias_warnings__ = unquote(orig_name)
      unquote_splicing(requireds)
      ProtocolEx.resolveProtocolEx_do(unquote(name), unquote(impls))
    end
  end

  defmacro resolve_protocol_ex(orig_name, impls, priority_sorted \\ false) when is_list(impls) do
    quote do
      ProtocolEx.resolveProtocolEx(unquote(orig_name), unquote(impls), unquote(priority_sorted))
    end
  end

  @doc false
  defmacro resolveProtocolEx_do(name, impls) when is_list(impls) do
    consolidate(name, impls: impls)
    if false do
    name = get_atom_name(name)
    desc_name = get_desc_name(name)
    spec = desc_name.spec()
    impl_quoted = {:__block__, [],
      Enum.map(impls, &quote(do: require unquote(&1))) ++
      :lists.reverse(spec.head_asts) ++
      [ quote do def __protocol_ex__, do: unquote(Macro.escape(clean_spec(spec))) end,
        quote do def __proto_ex_consolidated__, do: unquote(if(impls === [], do: false, else: true)) end,
        quote do def __proto_ex_impls__, do: unquote(impls) end
      ] ++
      Enum.flat_map(:lists.reverse(spec.callbacks), &load_abstract_from_impls(spec, name, &1, impls)) ++
      Enum.flat_map(spec.callbacks, &load_test_from_impls(name, &1, impls)) ++
      load_tests_from_impls(spec.callbacks)
    }
    # impl_quoted |> Macro.to_string() |> IO.puts
    if Code.ensure_loaded?(name) do
      :code.purge(name)
    end
    Code.compiler_options(ignore_module_conflict: true)
    #impl_quoted|> Macro.to_string()|>Code.format_string!()|>IO.puts()
    #impl_quoted|>IO.inspect()
    Module.create(name, impl_quoted, spec.location)
    Code.compiler_options(ignore_module_conflict: false)
    if(true, do: name.__tests_pex__([])) # TODO: Make this configurable
    end
    :ok
  end


  defp get_base_paths(opts) do
    case opts[:ebin_root] do
      nil -> :code.get_path()
      paths -> List.wrap(paths)
    end
  end


  defp globalize_ast(ast, env, scope) do
    Macro.prewalk(ast, fn
      {binding, ctx, nil} -> {binding, ctx, scope}
      {:__aliases__, _ctx, [arg | args]} = ast ->
        mod = Module.concat([arg])
        case env.aliases[mod] do
          nil -> ast
          mod -> Module.concat([mod | args])
        end
      ast -> ast
    end)
  end


  defp get_atom_name(name, env \\ %{module: nil})
  defp get_atom_name(name, env) when is_atom(name), do: Module.concat(get_env_name(env)++[name])
  defp get_atom_name({:__aliases__, _, names}, env) when is_list(names), do: Module.concat(get_env_name(env)++names)

  defp get_env_name(%{module: nil}), do: []
  defp get_env_name(%{module: module}), do: [module]

  defp get_atom_name_with(name, at_end) when is_atom(name) and is_atom(at_end), do: {:__aliases__, [alias: false], [name, at_end]}
  defp get_atom_name_with({:__aliases__, meta, names}, at_end) when is_list(names) and is_atom(at_end), do: {:__aliases__, meta, names ++ [at_end]}

  defp get_desc_name(name) when is_atom(name), do: Module.concat([name, @desc_name])

  defp get_impl_name(name, impl_name) when is_atom(name), do: Module.concat(name, impl_name)


  defp decompose_spec(env, as, body), do: decompose_spec(env, as, %Spec{as: as, location: Macro.Env.location(env)}, body)
  defp decompose_spec(env, as, returned, {:__block__, _, body}), do: decompose_spec(env, as, returned, body)
  defp decompose_spec(_env, _as, returned, []), do: returned
  defp decompose_spec(env, as, returned, [elem | rest]), do: decompose_spec(env, as, decompose_spec_element(env, as, returned, elem), rest)
  defp decompose_spec(env, as, returned, body), do: decompose_spec(env, as, returned, [body])


  defp decompose_spec_element(env, as, returned, elem)
  # defp decompose_spec_element(returned, {:def, meta, [{name, name_meta, noargs}]}) when is_atom(noargs), do: decompose_spec_element(returned, {:def, meta, [{name, name_meta, []}]})
  defp decompose_spec_element(_env, as, returned, {:def, _meta, [head]} = elem) do
    {name, args_length, defaults} = decompose_spec_head(as, head)
    elem = Macro.prewalk(elem, fn {:\\, _, [b, _]} -> b; a -> a end)
    callbacks = [{name, args_length, elem}] ++ defaults ++ returned.callbacks
    doc = List.wrap(returned.cache[:doc])
    %{returned |
      callbacks: callbacks,
      docs: if(doc === [], do: returned.docs, else: Map.put(returned.docs, {name, args_length}, doc)),
      cache: Map.put(returned.cache, :doc, [])
    }
  end
  defp decompose_spec_element(_env, as, returned, {:def, meta, [head, body]}) do
    {name, args_length, defaults} = decompose_spec_head(as, head)
    head = Macro.prewalk(head, fn {:\\, _, [b, _]} -> b; a -> a end)
    elem = {:def, meta, [head, body]}
    head = {:def, meta, [head]}
    callbacks = [{name, args_length, head, elem}] ++ defaults ++ returned.callbacks
    doc = List.wrap(returned.cache[:doc])
    %{returned |
      callbacks: callbacks,
      docs: if(doc === [], do: returned.docs, else: Map.put(returned.docs, {name, args_length}, doc)),
      cache: Map.put(returned.cache, :doc, [])
    }
  end
  defp decompose_spec_element(_env, _as, returned, {:deftest, meta, [{name, _, scope}, checks]}) when is_atom(scope) do
    callbacks = [{:extra, :test, name, meta, checks} | returned.callbacks]
    doc = List.wrap(returned.cache[:doc])
    %{returned |
      callbacks: callbacks,
      docs: if(doc === [], do: returned.docs, else: Map.put(returned.docs, name, doc)),
      cache: Map.put(returned.cache, :doc, [])
    }
  end
  defp decompose_spec_element(_env, _as, returned, {pt, _meta, _body} = ast) when pt in [
    :defmacro, :defmacrop, :defp,
    :spec, :type, :opaque,
    :moduledoc,
  ] do
    %{returned | head_asts: [ast | returned.head_asts]}
  end
  defp decompose_spec_element(_env, _as, returned, {:@, _meta, [{:doc, _doc_meta, _doc_args}]} = doc_ast) do
    %{returned | cache: Map.update(returned.cache, :doc, [doc_ast], &[doc_ast | &1])}
  end
  defp decompose_spec_element(_env, _as, returned, {:@, _meta, [{:moduledoc, _mdoc_meta, _mdoc_args}]} = mdoc_ast) do
    %{returned | docs: Map.update(returned.docs, :moduledoc, [mdoc_ast], &[mdoc_ast | &1])}
  end
  defp decompose_spec_element(env, _as, returned, {:@, _meta, [{:extends, _doc_meta, extending}]}) do
    extending = Enum.map(extending, fn
      {:__aliases__, _meta, names} ->
        m = Module.concat(names)
        env.aliases[m] || m
      name when is_atom(name) -> name
    end)
    %{returned | cache: Map.put(returned.cache, :extending, extending ++ List.wrap(returned.cache[:extending]))}
  end
  defp decompose_spec_element(env, _as, returned, {:require, _, requiring}) do
    requiring = Enum.map(requiring, fn
      {:__aliases__, _meta, names} ->
        m = Module.concat(names)
        env.aliases[m] || m
      name when is_atom(name) -> name
    end)
    %{returned | cache: Map.put(returned.cache, :requiring, requiring ++ List.wrap(returned.cache[:requiring]))}
  end
  defp decompose_spec_element(_env, _as, _returned, unhandled_elem), do: raise %InvalidProtocolSpecification{ast: unhandled_elem}


  defp decompose_spec_head(as, head)
  defp decompose_spec_head(as, {:when, _when_meta, [head, _guard]}) do
    decompose_spec_head(as, head)
  end
  defp decompose_spec_head(_as, {name, ctx, args} = _head) when is_atom(name) and is_list(args) do
    # if as != nil and args != [] do
    #   Enum.find(args, false, fn
    #     {^as, _, scope} when is_atom(scope) -> true
    #     _ -> false
    #   end) || raise %MissingAtInArgs{as: as, ast: head}
    # end
    defaults = generate_default_functions(name, ctx, args)
    {name, length(args), defaults}
  end
  defp decompose_spec_head(_as, head), do: raise %InvalidProtocolSpecification{ast: head}

  defp generate_default_functions(name, ctx, args_so_far \\ [], args, acc \\ [])
  defp generate_default_functions(_name, _ctx, _args_so_far, [], acc), do: acc
  defp generate_default_functions(name, ctx, args_so_far, [{:\\, _dctx, [_binding, default_ast]} | args], acc) do
    args_proc = Enum.filter(args, fn {:\\, _, _} -> false; _ -> true end)
    def_args = args_so_far ++ args_proc
    args_call = args_so_far ++ [default_ast] ++ args_proc
    args_so_far = args_so_far ++ [default_ast]
    def_head = {name, ctx, def_args}
    def_ast = {:def, ctx, [def_head, [do: {name, ctx, args_call}]]}
    default = {name, length(def_args), def_head, def_ast}
    generate_default_functions(name, ctx, args_so_far, args, [default | acc])
  end
  defp generate_default_functions(name, ctx, args_so_far, [arg | args], acc) do
    args_so_far = args_so_far ++ [arg]
    generate_default_functions(name, ctx, args_so_far, args, acc)
  end


  defp verify_valid_spec(spec) do
    # Sort callbacks
    spec_callbacks = Enum.sort(spec.callbacks, &>/2)
    # Verify only valid definitions
    callbacks = Enum.uniq_by(spec_callbacks, fn # The if's are to verify no 0-arity and 1-arity at same time
      {name, arity, _elem} -> {name, if(arity===0, do: 1, else: arity)}
      {name, arity, _elem_head, _elem} -> {name, if(arity===0, do: 1, else: arity)}
      {:extra, :test, name, _meta, _checks} -> {:extra, :test, name}
    end)
    # Verify no duplicate callback spec
    if length(spec_callbacks) !== length(callbacks) do
      [{name, arity, _elem}|_] = spec_callbacks -- callbacks
      case arity do
        0 -> raise %DuplicateSpecification{name: name, arity: -1}
        _ -> raise %DuplicateSpecification{name: name, arity: arity}
      end
    end
    %{spec | callbacks: callbacks}
  end


  defp verify_valid_spec_on_module(proto, spec, module) do
    spec.callbacks
    |> Enum.map(fn
      {name, arity, _} ->
        if :erlang.function_exported(module, name, arity) do
          :ok
        else
          try do
            mname = String.to_existing_atom("MACRO-#{name}")
            marity = arity + 1
            if :erlang.function_exported(module, mname, marity) do
              :ok
            else
              raise %MissingRequiredProtocolDefinition{proto: proto, impl: module, name: name, arity: arity}
            end
          rescue ArgumentError ->
            raise %MissingRequiredProtocolDefinition{proto: proto, impl: module, name: name, arity: arity}
          end
        end
      {_name, _arity, _, _} -> :ok
      {:extra, :test, _name, _meta, _checks} -> :ok
    end)
    :ok
  end


  defp gen_impl_test_asts(spec) do
    opts = Macro.var(:opts, nil)
    Enum.filter(spec.callbacks, fn
      {:extra, :test, _name, _meta, _checks} -> true
      _ -> false
    end)
    |> case do
      [] -> []
      tests ->
        Enum.map(tests, fn {:extra, :test, name, _meta, body} ->
          quote do
            def __tests_pex__(unquote(name), unquote(opts)) do
              _ = unquote(opts)
              unquote_splicing(List.wrap(body[:do]))
            end
          end
        end)
    end
  end


  def load_tests_from_impls(callbacks) do
    opts = Macro.var(:opts, __MODULE__)
    tests = Enum.flat_map(callbacks, fn
      {:extra, :test, name, _meta, _checks} ->
        [quote do
          __tests_pex__(unquote(name), unquote(opts))
        end]
      _ -> []
    end)
    [quote do
      def __tests_pex__(unquote(opts)) do
        unquote_splicing(tests)
      end
    end]
  end


  defp load_test_from_impls(proto, {:extra, :test, name, meta, _checks}, impls) do
    opts = Macro.var(:opts, __MODULE__)
    [quote do
      def __tests_pex__(unquote(name), unquote(opts)) do
        unquote_splicing(Enum.map(impls, fn impl ->
          quote do
            try do
              unquote(impl).__tests_pex__(unquote(name), unquote(opts))
            rescue
              ProtocolEx.UnimplementedProtocolEx -> :ok # Handling unimplemented specifically to allow overrides
              exc -> exc
            catch err -> err
            end
            |> case do
              {:ok, _value} -> :ok
              {:error, err_data} -> raise %ProtocolExTestFailure{
                proto: unquote(proto),
                type: unquote(impl),
                name: unquote(name),
                meta: unquote(meta),
                value: err_data,
              }
              :ok -> :ok
              true -> :ok
              nil -> :ok
              err_data -> raise %ProtocolExTestFailure{
                proto: unquote(proto),
                type: unquote(impl),
                name: unquote(name),
                meta: unquote(meta),
                value: err_data,
              }
            end
          end
        end))
      end
    end]
  end
  defp load_test_from_impls(_proto, _abstract, _impls), do: []


  defp load_abstract_from_impls(spec, pname, abstract, impls, returning \\ [])
  defp load_abstract_from_impls(spec, pname, abstract, impls, []) do
    doc_key =
      case abstract do
        {name, arity, _ast_head} -> {name, arity}
        {name, arity, _ast_head, _ast_fallback} -> {name, arity}
        {:extra, :test, name, _meta, _checks} -> name
      end
    doc =
      case spec.docs[doc_key] do
        nil -> [quote do @doc "<Undocumented>" end]
        ast -> ast
      end
    load_abstract_from_impls(spec, pname, abstract, impls, doc)
  end
  defp load_abstract_from_impls(spec, pname, abstract, [], returning) do
    case abstract do
      {name, 0, {def, meta, [{name, name_meta, []}]} = ast_head} ->
        body =
          {:raise, [context: Elixir, import: Kernel],
           [{:%, [],
             [{:__aliases__, [alias: false], [:ProtocolEx, :UnimplementedProtocolEx]},
              {:%{}, [],
                [proto: pname, name: name, arity: 0, value: []]
               }]}]}
        catch_all = append_body_to_head(ast_head, body)
        doc = quote do @doc unquote("See `#{name}/1`") end
        returning = returning ++ [catch_all, doc]
        arg = Macro.var(spec.as || :unused, __MODULE__)
        ast_head = {def, [generated: true] ++ meta, [{name, name_meta, [arg]}]}
        load_abstract_from_impls(spec, pname, {name, 1, ast_head}, [], returning)
      {name, arity, ast_head} ->
        args = Macro.generate_arguments(length(get_args_from_head(ast_head)), __MODULE__)
        head_args = Enum.map(args, &{:=, [generated: true], [@no_match, &1]})
        ast_head = replace_head_args_with(ast_head, head_args)
        ast_head = remove_guards(ast_head)
        body =
          {:raise, [context: Elixir, import: Kernel],
           [{:%, [],
             [{:__aliases__, [alias: false], [:ProtocolEx, :UnimplementedProtocolEx]},
              {:%{}, [],
                [proto: pname, name: name, arity: arity, value: args]
               }]}]}
        {c, cmeta, a} = append_body_to_head(ast_head, body)
        catch_all = {c, [generated: true] ++ cmeta, a}
        :lists.reverse(returning, [catch_all])
      {name, 0, _ast_head, {def, meta, [{name, name_meta, []}, _body]} = ast_fallback}  ->
        arg = Macro.var(spec.as || :unused, __MODULE__)
        ast_bounce = {def, [generated: true] ++ meta, [{name, name_meta, [arg]}, [do: quote do
            _ = unquote(arg)
            unquote(name)()
          end]]}
        doc = quote do @doc unquote("See `#{name}/1`") end
        :lists.reverse([ast_bounce | returning], [doc, ast_fallback])
      {_name, _arity, ast_head, {:def, meta, def_ast}}  ->
        {_ast_head, head_args} =
          Macro.prewalk(ast_head, [], fn
            {name, _meta, scope} = arg, acc when is_atom(name) and is_atom(scope) ->
              {arg, [arg | acc]}
            ast, acc ->
              {ast, acc}
          end)
        head_args =
          head_args
          |> Enum.uniq()
          |> Enum.map(&quote(do: _ = unquote(&1)))
        [body | def_ast] = :lists.reverse(def_ast)
        body = Keyword.put(body, :do, quote(do: (unquote_splicing(head_args);unquote(body[:do]))))
        def_ast = :lists.reverse(def_ast, [body])
        ast_fallback = {:def, meta, def_ast}
        :lists.reverse(returning, [ast_fallback])
      {:extra, :test, _name, _meta, _checks} -> []
    end
  end
  defp load_abstract_from_impls(spec, pname, abstract, [impl | impls], returning) do
    case abstract do
      {name, arity, ast_head} ->
        mname = String.to_atom("MACRO-#{name}")
        marity = arity + 1
        if Enum.any?(impl.module_info()[:exports], fn
          {^name, ^arity} -> true;
          {^mname, ^marity} -> true;
          _ -> false end) do
          {name, ast_head}
        else
          raise %MissingRequiredProtocolDefinition{proto: pname, impl: impl, name: name, arity: arity}
        end
      {name, arity, ast_head, _ast_fallback}  ->
        mname = String.to_atom("MACRO-#{name}")
        marity = arity + 1
        if Enum.any?(impl.module_info()[:exports], fn
          {^name, ^arity} -> true;
          {^mname, ^marity} -> true;
          _ -> false end) do
          {name, ast_head}
        else
          :skip
        end
      {:extra, :test, _name, _meta, _checks} = test -> test
    end
    |> case do
      :skip -> load_abstract_from_impls(spec, pname, abstract, impls, returning)
      {name, ast_head} ->
        matchers = List.wrap(impl.__matcher__())
        args = get_args_from_head(ast_head)
        arity = length(args)
        if :erlang.function_exported(impl, :__inlined__, 1) do
          impl.__inlined__({name, arity})
        else
          nil
        end
        |> case do
          nil ->
            body = build_body_call_with_args(impl, name, args)
            head_args =
              case bind_matcher_to_args(spec.as, matchers, args) do
                [] -> bind_matcher_to_args(spec.as, matchers, [Macro.var(:_, __MODULE__)]) # 0-arity to 1-arity of the matcher
                head_args -> head_args
              end
            ast_head = replace_head_args_with(ast_head, head_args)
            guard = get_guards_from_matchers(matchers)
            ast_head = add_guard_to_head(ast_head, guard)
            ast = append_body_to_head(ast_head, body)
            load_abstract_from_impls(spec, pname, abstract, impls, [ast | returning])
          inlined_impls when is_list(inlined_impls) ->
            guard = get_guards_from_matchers(matchers)
            inlined_impls =
              if(guard == true) do # TODO:  Maybe change this to force guard on inlined heads?  Probably not, maybe only on plain variables?
                Enum.map(inlined_impls, &add_guard_to_head(&1, guard))
              else
                inlined_impls
              end
            load_abstract_from_impls(spec, pname, abstract, impls, inlined_impls ++ returning)
        end
      {:extra, :test, _name, _meta, _checks} ->
        returning = [{impl} | returning]
        load_abstract_from_impls(spec, pname, abstract, impls, returning)
    end
  end

  defp get_args_from_head(ast_head)
  defp get_args_from_head({:def, _meta, [{:when, _when_meta, [{_name, _name_meta, args}, _guard]}]}) do
    args
  end
  defp get_args_from_head({:def, _meta, [{_name, _name_meta, args}]}) do
    args
  end

  defp bind_matcher_to_args(as, matcher, args, returned \\ [])
  defp bind_matcher_to_args(nil, _matcher, [], returned), do: :lists.reverse(returned)
  defp bind_matcher_to_args(nil, [], args, returned), do: :lists.reverse(returned, args)
  defp bind_matcher_to_args(nil, [{:when, _when_meta, [binding_ast, _when_call]} | matchers], [arg_ast | args], returned) do
    arg = {:=, [], [binding_ast, arg_ast]}
    bind_matcher_to_args(nil, matchers, args, [arg | returned])
  end
  defp bind_matcher_to_args(nil, [binding_ast | matchers], [arg_ast | args], returned) do
    arg = {:=, [], [binding_ast, arg_ast]}
    bind_matcher_to_args(nil, matchers, args, [arg | returned])
  end
  defp bind_matcher_to_args(as, [{:when, _when_meta, [binding_ast, _when_call]}], args, []) do
    Enum.map(args, fn
      {^as, meta, scope} = arg when is_atom(scope) -> {:=, meta, [generify_matcher_binding(binding_ast), arg]}
      arg -> arg
    end)
  end
  defp bind_matcher_to_args(as, [binding_ast], args, []) do
    Enum.map(args, fn
      {^as, meta, scope} = arg when is_atom(scope) -> {:=, meta, [generify_matcher_binding(binding_ast), arg]}
      arg -> arg
    end)
  end

  defp generify_matcher_binding(binding_ast), do: binding_ast # TODO to allow multiple binding locations?

  defp replace_head_args_with(ast_head, head_args)
  defp replace_head_args_with({:def, meta, [{:when, when_meta, [{name, name_meta, _args}, guards]} | rest]}, head_args) do
    {:def, meta, [{:when, when_meta, [{name, name_meta, head_args}, guards]} | rest]}
  end
  defp replace_head_args_with({:def, meta, [{name, name_meta, _args} | rest]}, head_args) do
    {:def, meta, [{name, name_meta, head_args} | rest]}
  end

  defp get_guards_from_matchers(matchers, returned \\ [])
  defp get_guards_from_matchers([], []), do: true
  defp get_guards_from_matchers([], returned), do: Enum.reduce(:lists.reverse(returned), fn(ast, acc) -> {:and, [], [ast, acc]} end)
  defp get_guards_from_matchers([{:when, _when_meta, [_bindings, guard]} | matchers], returned) do
    get_guards_from_matchers(matchers, [guard | returned])
  end
  defp get_guards_from_matchers([_when_ast | matchers], returned) do
    get_guards_from_matchers(matchers, returned)
  end

  defp add_guard_to_head(ast_head, guard)
  defp add_guard_to_head(ast_head, true), do: ast_head
  defp add_guard_to_head({:def, meta, [{:when, when_meta, [head, old_guard]} | rest]}, guard) do
    {:def, meta, [
      {:when, when_meta, [head, {:and, [], [old_guard, guard]}]}
      | rest
      ]}
  end
  defp add_guard_to_head({:def, meta, [head | rest]}, guard) do
    {:def, meta, [
      {:when, [], [head, guard]}
      | rest
      ]}
  end

  defp remove_guards(ast_head)
  defp remove_guards({:def, meta, [{:when, _when_meta, [head, _guard]} | body]}) do
    remove_guards({:def, meta, [head | body]})
  end
  defp remove_guards(ast), do: ast

  defp build_body_call_with_args(module, name, args) do
    quote do
      unquote(module).unquote(name)(unquote_splicing(args))
    end
  end

  defp append_body_to_head(ast_head, body)
  defp append_body_to_head({:def, meta, args}, body) do
    {:def, meta, args++[[do: body]]}
  end


  defp generate_alias_usage(ast, env) do
    Macro.prewalk(ast, [], fn
      {:__aliases__, _ctx, [name | _]} = ast, acc ->
        if env.aliases[Module.concat([name])] do
          {ast, [quote(do: _ = unquote(ast)) | acc]}
        else
          {ast, acc}
        end
      ast, acc ->
        {ast, acc}
    end)
    |> elem(1)
  end


end


if Mix.env() === :test do
  # MyDecimal for Numbers
  defimpl Numbers.Protocols.Addition, for: Tuple do
    def add({MyDecimal, _s0, :sNaN, _e0}, {MyDecimal, _s1, _c1, _e1}), do: throw :error
    def add({MyDecimal, _s0, _c0, _e0}, {MyDecimal, _s1, :sNaN, _e1}), do: throw :error
    def add({MyDecimal, _s0, :qNaN, _e0} = d0, {MyDecimal, _s1, _c1, _e1}), do: d0
    def add({MyDecimal, _s0, _c0, _e0}, {MyDecimal, _s1, :qNaN, _e1} = d1), do: d1
    def add({MyDecimal, s0, :inf, e0} = d0, {MyDecimal, s0, :inf, e1} = d1), do: if(e0 > e1, do: d0, else: d1)
    def add({MyDecimal, _s0, :inf, _e0}, {MyDecimal, _s1, :inf, _e1}), do: throw :error
    def add({MyDecimal, _s0, :inf, _e0} = d0, {MyDecimal, _s1, _c1, _e1}), do: d0
    def add({MyDecimal, _s0, _c0, _e0}, {MyDecimal, _s1, :inf, _e1} = d1), do: d1
    def add({MyDecimal, s0, c0, e0}, {MyDecimal, s1, c1, e1}) do
      {c0, c1} =
        cond do
          e0 === e1 -> {c0, c1}
          e0 > e1 -> {c0 * pow10(e0 - e1), c1}
          true -> {c0, c1 * pow10(e1 - e0)}
        end
      c = s0 * c0 + s1 * c1
      e = Kernel.min(e0, e1)
      s =
        cond do
          c > 0 -> 1
          c < 0 -> -1
          s0 == -1 and s1 == -1 -> -1
          # s0 != s1 and get_context().rounding == :floor -> -1
          true -> 1
        end
      {s, Kernel.abs(c), e}
    end
    def mult({MyDecimal, s0, c0, e0}, {MyDecimal, s1, c1, e1}) do
      s = s0 * s1
      {s, c0 * c1, e0 + e1}
    end
    def add_id(_num), do: {MyDecimal, 1, 0, 0}

    _pow10_max = Enum.reduce 0..104, 1, fn int, acc ->
      def pow10(unquote(int)), do: unquote(acc)
      def base10?(unquote(acc)), do: true
      acc * 10
    end
    def pow10(num) when num > 104, do: pow10(104) * pow10(num - 104)
  end

  defimpl Numbers.Protocols.Multiplication, for: Tuple do
    def mult({MyDecimal, _s0, :sNaN, _e0}, {MyDecimal, _s1, _c1, _e1}), do: throw :error
    def mult({MyDecimal, _s0, _c0, _e0}, {MyDecimal, _s1, :sNaN, _e1}), do: throw :error
    def mult({MyDecimal, _s0, :qNaN, _e0}, {MyDecimal, _s1, _c1, _e1}), do: throw :error
    def mult({MyDecimal, _s0, _c0, _e0}, {MyDecimal, _s1, :qNaN, _e1}), do: throw :error
    def mult({MyDecimal, _s0, 0, _e0}, {MyDecimal, _s1, :inf, _e1}), do: throw :error
    def mult({MyDecimal, _s0, :inf, _e0}, {MyDecimal, _s1, 0, _e1}), do: throw :error
    def mult({MyDecimal, s0, :inf, e0}, {MyDecimal, s1, _, e1}) do
      s = s0 * s1
      {s, :inf, e0+e1}
    end
    def mult({MyDecimal, s0, _, e0}, {MyDecimal, s1, :inf, e1}) do
      s = s0 * s1
      {s, :inf, e0+e1}
    end
    def mult({MyDecimal, s0, c0, e0}, {MyDecimal, s1, c1, e1}) do
      s = s0 * s1
      {s, c0 * c1, e0 + e1}
    end
    def mult_id(_num), do: {MyDecimal, 1, 1, 0}
  end
end
