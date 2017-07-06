defmodule ProtocolEx do
  @moduledoc """
  Documentation for ProtocolEx.
  """


  defmodule InvalidProtocolSpecification do
    defexception [ast: nil]
    def message(exc), do: "Unhandled specification node:  #{inspect exc.ast}"
  end

  defmodule DuplicateSpecification do
    defexception [name: nil, arity: 0]
    def message(exc), do: "Duplicate specification node:  #{inspect exc.name}/#{inspect exc.arity}"
  end

  defmodule UnimplementedProtocolEx do
    defexception [name: nil, arity: 0, value: nil]
    def message(exc), do: "Unimplemented Protocol at #{inspect exc.name}/#{inspect exc.arity} of value: #{inspect exc.value}"
  end


  defmodule Spec do
    defstruct [abstracts: []]
  end


  @desc_name :"$ProtocolEx_description$"


  @doc """

  ## Examples

      # iex> ProtocolEx.defprotocolEx
      # :world

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



  defmacro defimplEx(impl_name, matcher, [for: for_name], [do: body]) do
    name = get_atom_name(for_name)
    desc_name = get_desc_name(name)
    quote do
      require unquote(desc_name)
      ProtocolEx.defimplEx_do(unquote(Macro.escape(impl_name)), unquote(Macro.escape(matcher)), [for: unquote(Macro.escape(for_name))], [do: unquote(Macro.escape(body))], __ENV__)
    end
  end

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
      | verify_valid_spec_on_body(spec, body)
      ]}
    Module.create(impl_name, impl_quoted, Macro.Env.location(caller_env))
    nil
  end



  defmacro resolveProtocolEx(orig_name, impls) when is_list(impls) do
    name = get_atom_name(orig_name)
    desc_name = get_desc_name(name)
    quote do
      require unquote(desc_name)
      ProtocolEx.resolveProtocolEx_do(unquote(orig_name), unquote(impls))
    end
  end

  defmacro resolveProtocolEx_do(name, impls) when is_list(impls) do
    name = get_atom_name(name)
    desc_name = get_desc_name(name)
    spec = desc_name.spec()
    impls = Enum.map(impls, &get_atom_name/1)
    impls = Enum.map(impls, &get_atom_name_with(name, &1))
    impls = Enum.map(impls, &get_atom_name/1)
    impl_quoted = {:__block__, [],
      [ quote do def __protocolEx__, do: unquote(Macro.escape(spec)) end
      | Enum.flat_map(:lists.reverse(spec.abstracts), &load_abstract_from_impls(name, &1, impls))
      ]}
    impl_quoted |> Macro.to_string() |> IO.puts
    Module.create(name, impl_quoted, Macro.Env.location(__CALLER__))
    nil
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
  defp decompose_spec_element(returned, {:def, meta, [{name, name_meta, noargs}]}) when is_atom(noargs), do: decompose_spec_element(returned, {:def, meta, [{name, name_meta, []}]})
  defp decompose_spec_element(returned, {:def, _meta, [{name, _name_meta, args}]} = elem) when is_atom(name) and is_list(args) do
    abstracts = [{name, length(args), elem} | returned.abstracts]
    %{returned | abstracts: abstracts}
  end
  defp decompose_spec_element(_returned, unhandled_elem), do: raise %InvalidProtocolSpecification{ast: unhandled_elem}


  defp verify_valid_spec(spec) do
    abstracts = Enum.uniq_by(spec.abstracts, fn {name, arity, _elem} -> {name, arity} end)
    if length(spec.abstracts) !== length(abstracts) do
      [{name, arity, _elem}|_] = spec.abstracts -- abstracts
      raise %DuplicateSpecification{name: name, arity: arity}
    end
    spec
  end


  defp verify_valid_spec_on_body(spec, {:__block__, _, body}), do: verify_valid_spec_on_body(spec, body)
  defp verify_valid_spec_on_body(spec, body) when not is_list(body), do: verify_valid_spec_on_body(spec, [body])
  defp verify_valid_spec_on_body(_spec, body) do
    # TODO:  Quit being lazy and finish this check
    body
  end


  defp load_abstract_from_impls(pname, abstract, impls, returning \\ [])
  defp load_abstract_from_impls(_pname_, {name, arity, ast_head}, [], returning) when is_atom(name) and is_integer(arity) do
    body =
      {:raise, [context: Elixir, import: Kernel],
       [{:%, [],
         [{:__aliases__, [alias: false], [:ProtocolEx, :UnimplementedProtocolEx]},
          {:%{}, [],
           [name: name, arity: arity, value: {:value, [], nil}]
           }]}]}
    head_args = [{:value, [], nil} | tl(Enum.map(1..arity, fn _ -> {:_, [], nil} end))]
    ast_head = replace_head_args_with(ast_head, head_args)
    catch_all = append_body_to_head(ast_head, body)
    :lists.reverse(returning, [catch_all])
  end
  defp load_abstract_from_impls(pname, {name, arity, ast_head}=abstract, [impl | impls], returning) when is_atom(name) and is_integer(arity) do
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

  defp get_args_from_head(ast_head)
  defp get_args_from_head({:def, _meta, [{_name, _name_meta, args}]}) do
    Enum.map(args, fn
      {name, _, scope} = ast when is_atom(name) and is_atom(scope) -> ast
      end)
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
  defp replace_head_args_with({:def, meta, [{name, name_meta, _args} | rest]}, head_args) do
    {:def, meta, [{name, name_meta, head_args} | rest]}
  end

  def get_guards_from_matchers(matchers, returned \\ [])
  def get_guards_from_matchers([], []), do: true
  def get_guards_from_matchers([], returned), do: Enum.reduce(:lists.reverse(returned), fn(ast, acc) -> {:and, [], [ast, acc]} end)
  def get_guards_from_matchers([{:when, _when_meta, [_bindings, guard]} | matchers], returned) do
    get_guards_from_matchers(matchers, [guard | returned])
  end
  def get_guards_from_matchers([_when_ast | matchers], returned) do
    get_guards_from_matchers(matchers, returned)
  end

  defp add_guard_to_head(ast_head, guard)
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
