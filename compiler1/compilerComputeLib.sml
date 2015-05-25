structure compilerComputeLib = struct
local

open HolKernel boolLib bossLib computeLib
open modLangTheory source_to_modTheory
open conLangTheory mod_to_conTheory

fun add_compiler_compset compset = let
  fun add_datatype t = compute_basicLib.add_datatype t compset
  (* modLang *)
  val () = add_datatype ``:modLang$exp``
  val () = add_datatype ``:modLang$dec``
  val () = add_datatype ``:modLang$prompt``
  (* source_to_mod *)
  val () = add_thms
    [source_to_modTheory.compile_prog_def
    ,source_to_modTheory.compile_top_def
    ,source_to_modTheory.compile_decs_def
    ,source_to_modTheory.compile_dec_def
    ,source_to_modTheory.compile_exp_def
    ,source_to_modTheory.alloc_defs_def
    ,source_to_modTheory.Bool_def
    ] compset
  (* conLang *)
  val () = add_thms
    [bind_tag_def
    ,chr_tag_def
    ,div_tag_def
    ,eq_tag_def
    ,subscript_tag_def
    ,true_tag_def
    ,false_tag_def
    ,nil_tag_def
    ,cons_tag_def
    ,none_tag_def
    ,some_tag_def
    ] compset
  val () = add_datatype``:conLang$op``
  val () = add_datatype``:conLang$pat``
  val () = add_datatype``:conLang$exp``
  val () = add_datatype``:conLang$dec``
  val () = add_datatype``:conLang$prompt``
  (* mod_to_con *)
  val () = add_thms
    [mod_to_conTheory.compile_prog_def
    ,mod_to_conTheory.compile_prompt_def
    ,mod_to_conTheory.compile_decs_def
    ,mod_to_conTheory.compile_exp_def
    ,mod_to_conTheory.compile_pat_def
    ,mod_to_conTheory.lookup_tag_env_def
    ,mod_to_conTheory.lookup_tag_flat_def
    ,mod_to_conTheory.insert_tag_env_def
    ,mod_to_conTheory.mod_tagenv_def
    ,mod_to_conTheory.get_tagenv_def
    ,mod_to_conTheory.get_exh_def
    ,mod_to_conTheory.alloc_tag_def
    ,mod_to_conTheory.alloc_tags_def
    ] compset
in () end

in

val add_compiler_compset = add_compiler_compset

val the_compiler_compset =
  let
    val c = compute_basicLib.the_basic_compset
    val () = compute_semanticsLib.add_ast_compset c
    val () = add_compiler_compset c
  in
    c
  end

end
end
