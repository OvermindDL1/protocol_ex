defmodule ProtocolEx do
  @moduledoc """
  Matcher protocol control module
  """


  defmodule InvalidProtocolSpecification do
    @moduledoc """
    This is raised when a protocol definition is invalid.

    If a new feature is wanted in the protocol definition, please raise an issue or submit a PR.
    """
    defexception [ast: nil]
    def message(exc), do: "Unhandled specification node:  #{inspect exc.ast}"
  end

  defmodule DuplicateSpecification do
    @moduledoc """
    Only one implementation for a given callback per implementaiton is allowed at this time.
    """
    defexception [name: nil, arity: 0]
    def message(exc), do: "Duplicate specification node:  #{inspect exc.name}/#{inspect exc.arity}"
  end

  defmodule UnimplementedProtocolEx do
    @moduledoc """
    Somehow a given implementation was consolidated without actually having a required callback specified.
    """
    defexception [proto: nil, name: nil, arity: 0, value: nil]
    def message(exc), do: "Unimplemented Protocol of `#{exc.prot}` at #{inspect exc.name}/#{inspect exc.arity} of value: #{inspect exc.value}"
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


  defmodule Spec do
    @moduledoc false
    defstruct [callbacks: []]
  end


  @desc_name :"$ProtocolEx_description$"


  @doc """
  Define a protocol behaviour.
  """
  defmacro defprotocolEx(name, [do: body]) do
    # parsed_name = get_atom_name(name)
    # desc_name = get_desc_name(parsed_name)
    desc_name = get_atom_name_with(name, @desc_name)
    spec = decompose_spec(body)
    spec = verify_valid_spec(spec)
    quote do
      defmodule unquote(desc_name) do
        def spec, do: unquote(Macro.escape(spec))
      end
    end
  end



  @doc """
  Implement a protocol based on a matcher specification
  """
  defmacro defimplEx(impl_name, matcher, [for: for_name], [do: body]) do
    name = get_atom_name(for_name)
    name = __CALLER__.aliases[name] || name
    desc_name = get_desc_name(name)
    quote do
      require unquote(desc_name)
      ProtocolEx.defimplEx_do(unquote(Macro.escape(impl_name)), unquote(Macro.escape(matcher)), [for: unquote(Macro.escape(name))], [do: unquote(Macro.escape(body))], __ENV__)
    end
  end

  @doc false
  def defimplEx_do(impl_name, matcher, [for: name], [do: body], caller_env) do
    name = get_atom_name(name)
    desc_name = get_desc_name(name)
    impl_name = get_atom_name(impl_name)
    impl_name = get_impl_name(name, impl_name)
    impl_name = get_atom_name(impl_name)
    spec = desc_name.spec()
    impl_quoted = {:__block__, [],
      [ quote do
          def __matcher__, do: unquote(Macro.escape(matcher))
        end,
        quote do
          def __spec__, do: unquote(desc_name).spec()
        end
      | List.wrap(body)
      ]}
    # impl_quoted |> Macro.to_string() |> IO.puts
    if Code.ensure_loaded?(impl_name) do
      :code.purge(impl_name)
    end
    Module.create(impl_name, impl_quoted, Macro.Env.location(caller_env))
    verify_valid_spec_on_module(name, spec, impl_name)
  end



  @doc """
  Resolve a protocol into a final ready-to-use-module
  """
  defmacro resolveProtocolEx(orig_name, impls) when is_list(impls) do
    name = get_atom_name(orig_name)
    name = __CALLER__.aliases[name] || name
    desc_name = get_desc_name(name)
    impls = Enum.map(impls, &get_atom_name/1)
    impls = Enum.map(impls, &get_atom_name_with(name, &1))
    impls = Enum.map(impls, &get_atom_name/1)
    requireds = Enum.map([desc_name | impls], fn req ->
      {:require, [], [req]}
      # quote do
      #   require unquote(req)
      # end
    end)
    quote do
      __silence_alias_warnings__ = unquote(orig_name)
      unquote_splicing(requireds)
      ProtocolEx.resolveProtocolEx_do(unquote(name), unquote(impls))
    end
  end

  @doc false
  defmacro resolveProtocolEx_do(name, impls) when is_list(impls) do
    name = get_atom_name(name)
    desc_name = get_desc_name(name)
    spec = desc_name.spec()
    impl_quoted = {:__block__, [],
      [ quote do def __protocolEx__, do: unquote(Macro.escape(spec)) end
      | Enum.flat_map(:lists.reverse(spec.callbacks), &load_abstract_from_impls(name, &1, impls))
      ]}
    # impl_quoted |> Macro.to_string() |> IO.puts
    if Code.ensure_loaded?(name) do
      :code.purge(name)
    end
    Module.create(name, impl_quoted, Macro.Env.location(__CALLER__))
    :ok
  end



  defp get_atom_name(name) when is_atom(name), do: name
  defp get_atom_name({:__aliases__, _, names}) when is_list(names), do: Module.concat(names)

  defp get_atom_name_with(name, at_end) when is_atom(name) and is_atom(at_end), do: {:__aliases__, [alias: false], [name, at_end]}
  defp get_atom_name_with({:__aliases__, meta, names}, at_end) when is_list(names) and is_atom(at_end), do: {:__aliases__, meta, names ++ [at_end]}

  defp get_desc_name(name) when is_atom(name), do: Module.concat([name, @desc_name])

  defp get_impl_name(name, impl_name) when is_atom(name), do: Module.concat(name, impl_name)


  defp decompose_spec(returned \\ %Spec{}, body)
  defp decompose_spec(returned, {:__block__, _, body}), do: decompose_spec(returned, body)
  defp decompose_spec(returned, []), do: returned
  defp decompose_spec(returned, [elem | rest]), do: decompose_spec(decompose_spec_element(returned, elem), rest)
  defp decompose_spec(returned, body), do: decompose_spec(returned, [body])


  defp decompose_spec_element(returned, elem)
  # defp decompose_spec_element(returned, {:def, meta, [{name, name_meta, noargs}]}) when is_atom(noargs), do: decompose_spec_element(returned, {:def, meta, [{name, name_meta, []}]})
  defp decompose_spec_element(returned, {:def, _meta, [head]} = elem) do
    {name, args_length} = decompose_spec_head(head)
    callbacks = [{name, args_length, elem} | returned.callbacks]
    %{returned | callbacks: callbacks}
  end
  defp decompose_spec_element(returned, {:def, meta, [head, _body]}=elem) do
    {name, args_length} = decompose_spec_head(head)
    head = {:def, meta, [head]}
    callbacks = [{name, args_length, head, elem} | returned.callbacks]
    %{returned | callbacks: callbacks}
  end
  defp decompose_spec_element(_returned, unhandled_elem), do: raise %InvalidProtocolSpecification{ast: unhandled_elem}


  defp decompose_spec_head(head)
  defp decompose_spec_head({:when, _when_meta, [head, _guard]}) do
    decompose_spec_head(head)
  end
  defp decompose_spec_head({name, _name_meta, args}) when is_atom(name) and is_list(args) do
    {name, length(args)}
  end
  defp decompose_spec_head(head), do: raise %InvalidProtocolSpecification{ast: head}


  defp verify_valid_spec(spec) do
    callbacks = Enum.uniq_by(spec.callbacks, fn
      {name, arity, _elem} -> {name, arity}
      {name, arity, _elem_head, _elem} -> {name, arity}
    end)
    if length(spec.callbacks) !== length(callbacks) do
      [{name, arity, _elem}|_] = spec.callbacks -- callbacks
      raise %DuplicateSpecification{name: name, arity: arity}
    end
    spec
  end


  defp verify_valid_spec_on_module(proto, spec, module) do
    spec.callbacks
    |> Enum.map(fn
      {name, arity, _} ->
        if :erlang.function_exported(module, name, arity) do
          :ok
        else
          raise  %MissingRequiredProtocolDefinition{proto: proto, impl: module, name: name, arity: arity}
        end
      {_name, _arity, _, _} -> :ok
    end)
    :ok
  end


  defp load_abstract_from_impls(pname, abstract, impls, returning \\ [])
  defp load_abstract_from_impls(pname, abstract, [], returning) do
    case abstract do
      {name, arity, ast_head} ->
        args = get_args_from_head(ast_head)
        first_arg = hd(args)
        rest_args = tl(args)
        rest_args =
          Enum.map(rest_args, fn arg ->
            quote do
              _ = unquote(arg)
            end
          end)
        body =
          {:raise, [context: Elixir, import: Kernel],
           [{:%, [],
             [{:__aliases__, [alias: false], [:ProtocolEx, :UnimplementedProtocolEx]},
              {:%{}, [],
               [proto: pname, name: name, arity: arity, value: first_arg]
               }]}]}
        body =
          quote do
            unquote_splicing(rest_args)
            unquote(body)
          end
        catch_all = append_body_to_head(ast_head, body)
        :lists.reverse(returning, [catch_all])
      {_name, _arity, _ast_head, ast_fallback}  ->
        :lists.reverse(returning, [ast_fallback])
    end
  end
  defp load_abstract_from_impls(pname, abstract, [impl | impls], returning) do
    case abstract do
      {name, arity, ast_head} ->
        if Enum.any?(impl.module_info()[:exports], fn {^name, ^arity} -> true; _ -> false end) do
          {name, ast_head}
        else
          raise %MissingRequiredProtocolDefinition{proto: pname, impl: impl, name: name, arity: arity}
        end
      {name, arity, ast_head, _ast_fallback}  ->
        if Enum.any?(impl.module_info()[:exports], fn {^name, ^arity} -> true; _ -> false end) do
          {name, ast_head}
        else
          :skip
        end
    end
    |> case do
      :skip -> load_abstract_from_impls(pname, abstract, impls, returning)
      {name, ast_head} ->
        matchers = List.wrap(impl.__matcher__())
        args = get_args_from_head(ast_head)
        body = build_body_call_with_args(impl, name, args)
        head_args = bind_matcher_to_args(matchers, args)
        ast_head = replace_head_args_with(ast_head, head_args)
        guard = get_guards_from_matchers(matchers)
        ast_head = if(guard == true, do: ast_head, else: add_guard_to_head(ast_head, guard))
        ast = append_body_to_head(ast_head, body)
        load_abstract_from_impls(pname, abstract, impls, [ast | returning])
    end
  end

  defp get_args_from_head(ast_head)
  defp get_args_from_head({:def, _meta, [{:when, _when_meta, [{_name, _name_meta, args}, _guard]}]}) do
    # Enum.map(List.wrap(args), fn
    #   {name, _, scope} = ast when is_atom(name) and is_atom(scope) -> ast
    #   end)
    args
  end
  defp get_args_from_head({:def, _meta, [{_name, _name_meta, args}]}) do
    # Enum.map(List.wrap(args), fn
    #   {name, _, scope} = ast when is_atom(name) and is_atom(scope) -> ast
    #   end)
    args
  end

  defp bind_matcher_to_args(matcher, args, returned \\ [])
  defp bind_matcher_to_args(_matcher, [], returned), do: :lists.reverse(returned)
  defp bind_matcher_to_args([], args, returned), do: :lists.reverse(returned, args)
  defp bind_matcher_to_args([{:when, _when_meta, [binding_ast, _when_call]} | matchers], [arg_ast | args], returned) do
    arg = {:=, [], [binding_ast, arg_ast]}
    bind_matcher_to_args(matchers, args, [arg | returned])
  end
  defp bind_matcher_to_args([binding_ast | matchers], [arg_ast | args], returned) do
    arg = {:=, [], [binding_ast, arg_ast]}
    bind_matcher_to_args(matchers, args, [arg | returned])
  end

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

  defp build_body_call_with_args(module, name, args) do
    quote do
      unquote(module).unquote(name)(unquote_splicing(args))
    end
  end

  defp append_body_to_head(ast_head, body)
  defp append_body_to_head({:def, meta, args}, body), do: {:def, meta, args++[[do: body]]}
end
