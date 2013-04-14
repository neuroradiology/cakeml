open HolKernel bossLib boolLib boolSimps intLib pairTheory sumTheory listTheory pred_setTheory finite_mapTheory alistTheory lcsymtacs
open MiniMLTheory MiniMLTerminationTheory miniMLExtraTheory evaluateEquationsTheory miscTheory intLangTheory compileTerminationTheory pmatchTheory
val _ = new_theory "expToCexp"
val fsd = full_simp_tac std_ss

(* Nicer induction *)

val exp_to_Cexp_nice_ind = save_thm(
"exp_to_Cexp_nice_ind",
exp_to_Cexp_ind
|> Q.SPECL [`P`
   ,`λs defs. EVERY (λ(d,t1,vn,t2,e). P s e) defs`
   ,`λs pes. EVERY (λ(p,e). P s e) pes`
   ,`λs. EVERY (P s)`]
|> SIMP_RULE (srw_ss()) []
|> UNDISCH_ALL
|> CONJUNCTS
|> el 1
|> DISCH_ALL
|> Q.GEN `P`
|> SIMP_RULE (srw_ss()) [optionTheory.option_case_compute,cond_sum_expand])

(* Misc. lemmas *)

val do_Opapp_SOME_CRecClos = store_thm(
"do_Opapp_SOME_CRecClos",
``(do_app s env Opapp v1 v2 = SOME (s',env',exp'')) ∧
  syneq c1 c2 (v_to_Cv m v1) w1 ⇒
  ∃env'' defs n.
    (w1 = CRecClos env'' defs n)``,
Cases_on `v1` >> rw[do_app_def,v_to_Cv_def,LET_THM] >>
fs[defs_to_Cdefs_MAP, Once syneq_cases])

val env_to_Cenv_APPEND = store_thm("env_to_Cenv_APPEND",
  ``env_to_Cenv m (l1 ++ l2) = env_to_Cenv m l1 ++ env_to_Cenv m l2``,
  rw[env_to_Cenv_MAP])
val _ = export_rewrites["env_to_Cenv_APPEND"]

val all_Clocs_v_to_Cv = store_thm("all_Clocs_v_to_Cv",
  ``(∀m (v:α v). all_Clocs (v_to_Cv m v) = all_locs v) ∧
    (∀m (vs:α v list). MAP all_Clocs (vs_to_Cvs m vs) = MAP all_locs vs) ∧
    (∀m env: α envE. MAP all_Clocs (env_to_Cenv m env) = MAP (all_locs o FST o SND) env)``,
  ho_match_mp_tac v_to_Cv_ind >>
  srw_tac[ETA_ss][v_to_Cv_def,LET_THM,defs_to_Cdefs_MAP] >>
  fs[GSYM LIST_TO_SET_MAP,MAP_MAP_o])

(* free vars lemmas *)

val Cpat_vars_pat_to_Cpat = store_thm(
"Cpat_vars_pat_to_Cpat",
``(∀(p:α pat) s pvs pvs' Cp. (pat_to_Cpat s pvs p = (pvs',Cp))
  ⇒ (Cpat_vars Cp = pat_vars p)) ∧
  (∀(ps:α pat list) s pvs pvs' Cps. (pats_to_Cpats s pvs ps = (pvs',Cps))
  ⇒ (MAP Cpat_vars Cps = MAP pat_vars ps))``,
ho_match_mp_tac (TypeBase.induction_of ``:α pat``) >>
rw[pat_to_Cpat_def,LET_THM,pairTheory.UNCURRY] >>
rw[FOLDL_UNION_BIGUNION,IMAGE_BIGUNION] >- (
  qabbrev_tac `q = pats_to_Cpats s' pvs ps` >>
  PairCases_on `q` >>
  fsrw_tac[ETA_ss][MAP_EQ_EVERY2,EVERY2_EVERY,EVERY_MEM,pairTheory.FORALL_PROD] >>
  AP_TERM_TAC >>
  first_x_assum (qspecl_then [`s'`,`pvs`] mp_tac) >>
  rw[] >>
  pop_assum mp_tac >>
  rw[MEM_ZIP] >>
  rw[Once EXTENSION,MEM_EL] >>
  PROVE_TAC[] )
>- (
  qabbrev_tac `q = pat_to_Cpat s pvs p` >>
  PairCases_on `q` >>
  fs[] >>
  PROVE_TAC[] )
>- (
  qabbrev_tac `q = pats_to_Cpats s pvs ps` >>
  PairCases_on `q` >>
  qabbrev_tac `r = pat_to_Cpat s q0 p` >>
  PairCases_on `r` >>
  fs[] >>
  PROVE_TAC[] )
>- (
  fs[Once pat_to_Cpat_empty_pvs] ))

val Cpat_vars_SND_pat_to_Cpat = store_thm("Cpat_vars_SND_pat_to_Cpat",
  ``Cpat_vars (SND (pat_to_Cpat s [] z)) = pat_vars z``,
  Cases_on `pat_to_Cpat s [] z` >>
  imp_res_tac Cpat_vars_pat_to_Cpat >>
  rw[])
val _ = export_rewrites["Cpat_vars_SND_pat_to_Cpat"]

val free_vars_exp_to_Cexp = store_thm(
"free_vars_exp_to_Cexp",
``∀s e. free_vars FEMPTY (exp_to_Cexp s e) = FV e``,
ho_match_mp_tac exp_to_Cexp_nice_ind >>
srw_tac[ETA_ss,DNF_ss][exp_to_Cexp_def,exps_to_Cexps_MAP,pes_to_Cpes_MAP,defs_to_Cdefs_MAP,
FOLDL_UNION_BIGUNION,IMAGE_BIGUNION,BIGUNION_SUBSET,LET_THM,EVERY_MEM] >>
rw[] >- (
  AP_TERM_TAC >>
  rw[Once EXTENSION] >>
  fsrw_tac[DNF_ss][MEM_MAP,EVERY_MEM] >>
  PROVE_TAC[] )
>- (
  BasicProvers.EVERY_CASE_TAC >> rw[] >>
  srw_tac[DNF_ss][Once EXTENSION] >>
  metis_tac[NOT_fresh_var,FINITE_FV])
>- (
  BasicProvers.EVERY_CASE_TAC >> rw[] )
>- (
  Q.PAT_ABBREV_TAC`v = fresh_var X` >>
  Q.PAT_ABBREV_TAC`pe = MAP (X:(α pat#α exp)->(Cpat#Cexp)) pes` >>
  qabbrev_tac`y = FV e` >>
  qspecl_then [`v`,`pe`] mp_tac free_vars_remove_mat_var >>
  asm_simp_tac std_ss [EXTENSION,IN_DIFF,IN_SING,IN_UNION] >>
  strip_tac >>
  qx_gen_tac `u` >>
  Cases_on `u ∈ y` >> fsd[] >>
  qunabbrev_tac `y` >>
  fsd[pairTheory.FORALL_PROD] >>
  Cases_on `u=v` >> fsd[] >- (
    qunabbrev_tac`v` >>
    match_mp_tac fresh_var_not_in_any >>
    pop_assum kall_tac >>
    ntac 2 (pop_assum kall_tac) >>
    fsrw_tac[DNF_ss][SUBSET_DEF,pairTheory.FORALL_PROD,
                     Abbr`pe`,Cpes_vars_thm] >>
    fsrw_tac[DNF_ss][MAP_MAP_o,combinTheory.o_DEF,
                     pairTheory.LAMBDA_PROD] >>
    fsrw_tac[DNF_ss][MEM_MAP,pairTheory.EXISTS_PROD] >>
    fsrw_tac[DNF_ss][pairTheory.UNCURRY] >>
    map_every qx_gen_tac [`x`,`y`,`z`] >>
    strip_tac >>
    disj2_tac >>
    map_every qexists_tac [`y`,`z`] >>
    rw[] >> PROVE_TAC[] ) >>
  fsrw_tac[DNF_ss][pairTheory.EXISTS_PROD] >>
  fsrw_tac[DNF_ss][Abbr`pe`,MEM_MAP,pairTheory.EXISTS_PROD] >>
  fsrw_tac[DNF_ss][pairTheory.UNCURRY] >>
  rw[Once CONJ_ASSOC] >>
  qho_match_abbrev_tac `
    (∃p1 p2. A p1 p2 ∧ MEM (p1,p2) pes) =
    (∃p1 p2. B p1 p2 ∧ MEM (p1,p2) pes)` >>
  (qsuff_tac `∀p1 p2. MEM (p1,p2) pes ⇒ (A p1 p2 = B p1 p2)` >- PROVE_TAC[]) >>
  srw_tac[DNF_ss][Abbr`A`,Abbr`B`] >>
  first_x_assum (qspecl_then [`p1`,`p2`] mp_tac) >>
  rw[])
>- (
  fs[FOLDL_UNION_BIGUNION_paired] >>
  qmatch_abbrev_tac `X ∪ Y = Z ∪ A` >>
  `X = A` by (
    fs[markerTheory.Abbrev_def] >>
    rw[LIST_TO_SET_MAP] ) >>
  rw[UNION_COMM] >>
  unabbrev_all_tac >>
  ntac 2 AP_TERM_TAC >>
  rw[Once EXTENSION,pairTheory.EXISTS_PROD,LIST_TO_SET_MAP,DIFF_UNION,DIFF_COMM] >>
  srw_tac[DNF_ss][MEM_MAP,pairTheory.EXISTS_PROD,pairTheory.UNCURRY] >>
  fs[pairTheory.FORALL_PROD] >>
  PROVE_TAC[] )
>- (
  qabbrev_tac `q = pat_to_Cpat s [] p` >>
  PairCases_on`q`>>fs[] )
>- (
  qabbrev_tac `q = pat_to_Cpat s [] p` >>
  PairCases_on`q`>>fs[] ))
val _ = export_rewrites["free_vars_exp_to_Cexp"];

(* closed lemmas *)

val v_to_Cv_closed = store_thm(
"v_to_Cv_closed",
``(∀m (v:α v). closed v ⇒ Cclosed FEMPTY (v_to_Cv m v)) ∧
  (∀m (vs:α v list). EVERY closed vs ⇒ EVERY (Cclosed FEMPTY) (vs_to_Cvs m vs)) ∧
  (∀m (env:α envE). EVERY closed (MAP (FST o SND) env) ⇒ FEVERY ((Cclosed FEMPTY) o SND) (alist_to_fmap (env_to_Cenv m env)))``,
ho_match_mp_tac v_to_Cv_ind >>
rw[v_to_Cv_def] >> rw[Cclosed_rules]
>- (
  fs[Once closed_cases] >>
  rw[Once Cclosed_cases,Abbr`Ce`,Abbr`Cenv`,env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_triple] >>
  fs[SUBSET_DEF] >> PROVE_TAC[])
>- (
  fs[Once closed_cases] >>
  fs[defs_to_Cdefs_MAP] >> rw[] >>
  rw[Once Cclosed_cases,Abbr`Cenv`,env_to_Cenv_MAP] >- (
    Cases_on `defs` >> fs[] ) >>
  pop_assum mp_tac >> rw[EL_MAP] >>
  qabbrev_tac `p = EL i defs` >>
  PairCases_on `p` >> fs[] >> rw[] >>
  rw[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_triple] >>
  fs[SUBSET_DEF] >> PROVE_TAC[] ) >>
first_x_assum (match_mp_tac o MP_CANON) >>
pop_assum mp_tac >>
rw[FRANGE_DEF,DOMSUB_FAPPLY_THM] >>
rw[] >> PROVE_TAC[])

(* do_app SOME lemmas *)

val do_app_Opn_SOME = store_thm("do_app_Opn_SOME",
  ``(do_app s env (Opn opn) v1 v2 = SOME (s',env',exp')) =
    ((s' = s) ∧ (env' = env) ∧
     ∃n1 n2. (v1 = Litv (IntLit n1)) ∧ (v2 = Litv (IntLit n2)) ∧
      (exp' =
       if (n2 = 0) ∧ ((opn = Divide) ∨ (opn = Modulo)) then
         Raise Div_error
       else Lit (IntLit (opn_lookup opn n1 n2))))``,
  Cases_on`opn`>>
  Cases_on`v1`>>TRY(Cases_on`l`)>>
  Cases_on`v2`>>TRY(Cases_on`l`)>>
  rw[do_app_def,opn_lookup_def] >>
  rw[EQ_IMP_THM])

val do_app_Opb_SOME = store_thm("do_app_Opb_SOME",
  ``(do_app s env (Opb opb) v1 v2 = SOME (s',env',exp')) =
    ((s' = s) ∧ (env' = env) ∧
     ∃n1 n2. (v1 = Litv (IntLit n1)) ∧ (v2 = Litv (IntLit n2)) ∧
      (exp' = Lit (Bool (opb_lookup opb n1 n2))))``,
  Cases_on`opb`>>
  Cases_on`v1`>>TRY(Cases_on`l`)>>
  Cases_on`v2`>>TRY(Cases_on`l`)>>
  rw[do_app_def,opb_lookup_def] >>
  rw[EQ_IMP_THM])

val do_app_Opapp_SOME = store_thm("do_app_Opapp_SOME",
``(do_app s env_ Opapp v1 v2 = SOME (s',env',exp')) =
  ((s' = s) ∧
   ((∃env n to e. (v1 = Closure env n to e) ∧
                  (env' = bind n (v2,add_tvs (SOME 0) to) env) ∧
                  (exp' = e)) ∨
    (∃env funs n to m.
      (v1 = Recclosure env funs n) ∧
      (find_recfun n funs = SOME (m,to,exp')) ∧
      (env' = bind m (v2,add_tvs(SOME 0) to) (build_rec_env (SOME 0) funs env)))))``,
  Cases_on`v1`>>rw[do_app_def] >- rw[EQ_IMP_THM] >>
  BasicProvers.EVERY_CASE_TAC >>
  fs[optionTheory.OPTION_MAP_EQ_NONE] >>
  rw[EQ_IMP_THM] >>
  pop_assum (assume_tac o SYM) >> fs[])

(* correctness *)

(*
val v_to_Cv_inj_rwt = store_thm(
"v_to_Cv_inj_rwt",
``∀s v1 v2. (v_to_Cv s v1 = v_to_Cv s v2) = (v1 = v2)``,
probably not true until equality is corrected in the source language *)

(* TODO: categorise *)

val pat_to_Cpat_deBruijn_subst_p = store_thm("pat_to_Cpat_deBruijn_subst_p",
  ``(∀p n x m. pat_to_Cpat m (deBruijn_subst_p n x p) = pat_to_Cpat m p) ∧
    (∀ps n x m. pats_to_Cpats m (MAP (deBruijn_subst_p n x) ps) = pats_to_Cpats m ps)``,
  ho_match_mp_tac (TypeBase.induction_of``:t pat``) >>
  srw_tac[ETA_ss][deBruijn_subst_p_def,pat_to_Cpat_def])
val _ = export_rewrites["pat_to_Cpat_deBruijn_subst_p"]

val exp_to_Cexp_deBruijn_subst_e = store_thm("exp_to_Cexp_deBruijn_subst_e",
  ``∀n x e m. exp_to_Cexp m (deBruijn_subst_e n x e) = exp_to_Cexp m e``,
  ho_match_mp_tac deBruijn_subst_e_ind >>
  srw_tac[ETA_ss][deBruijn_subst_e_def] >>
  rw[exp_to_Cexp_def,exps_to_Cexps_MAP,MAP_MAP_o,MAP_EQ_f,
     defs_to_Cdefs_MAP,pes_to_Cpes_MAP,LET_THM,FORALL_PROD]
  >- ( Cases_on`bop`>>rw[exp_to_Cexp_def] )
  >- ( rw[UNCURRY,combinTheory.o_DEF] >>
       AP_TERM_TAC >>
       rw[MAP_EQ_f,FORALL_PROD] >>
       AP_TERM_TAC >>
       res_tac >> rw[] ) >>
  rw[UNCURRY,combinTheory.o_DEF] >>
  rw[LAMBDA_PROD] >>
  metis_tac[])
val _ = export_rewrites["exp_to_Cexp_deBruijn_subst_e"]

val v_to_Cv_deBruijn_subst_v = store_thm("v_to_Cv_deBruijn_subst_v",
  ``∀x v m. v_to_Cv m (deBruijn_subst_v x v) = v_to_Cv m v``,
  ho_match_mp_tac deBruijn_subst_v_ind >>
  srw_tac[ETA_ss][deBruijn_subst_v_def,v_to_Cv_def,LET_THM,
                  defs_to_Cdefs_MAP,vs_to_Cvs_MAP,MAP_MAP_o,MAP_EQ_f,FORALL_PROD] >>
  rw[combinTheory.o_DEF,UNCURRY,LAMBDA_PROD])
val _ = export_rewrites["v_to_Cv_deBruijn_subst_v"]

val v_to_Cv_do_tapp = store_thm("v_to_Cv_do_tapp",
  ``∀ts to v m. v_to_Cv m (do_tapp ts to v) = v_to_Cv m v``,
  rw[do_tapp_def] >>
  BasicProvers.EVERY_CASE_TAC >>
  rw[])
val _ = export_rewrites["v_to_Cv_do_tapp"]

val exp_to_Cexp_thm1 = store_thm("exp_to_Cexp_thm1",
  ``(∀cenv s env exp res. evaluate cenv s env exp res ⇒
     good_cenv cenv ∧ (SND res ≠ Rerr Rtype_error) ⇒
     ∀m. good_cmap cenv m.cnmap ⇒
       Cevaluate FEMPTY
         (MAP (v_to_Cv m) s)
         (env_to_Cenv m env)
         (exp_to_Cexp (m with bvars := MAP FST env ++ m.bvars) exp)
         (MAP (v_to_Cv m) (FST res)
         ,map_result (v_to_Cv m) (SND res)))∧
    (∀cenv s env exps res. evaluate_list cenv s env exps res ⇒
     good_cenv cenv ∧ (SND res ≠ Rerr Rtype_error) ⇒
     ∀m. good_cmap cenv m.cnmap ⇒
       Cevaluate_list FEMPTY
         (MAP (v_to_Cv m) s)
         (env_to_Cenv m env)
         (MAP (exp_to_Cexp (m with bvars := MAP FST env ++ m.bvars)) exps)
         (MAP (v_to_Cv m) (FST res)
         ,map_result (MAP (v_to_Cv m)) (SND res)))``,
  ho_match_mp_tac evaluate_nicematch_strongind >>
  strip_tac >- rw[exp_to_Cexp_def,v_to_Cv_def] >>
  strip_tac >- rw[exp_to_Cexp_def] >>
  strip_tac >- (
    rw[exp_to_Cexp_def] >> fs[] >>
    first_x_assum(qspec_then`m`mp_tac) >> rw[] >>
    rw[Once Cevaluate_cases]) >>
  strip_tac >- (
    rw[exp_to_Cexp_def] >> fs[bind_def] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    disj2_tac >> disj1_tac >>
    fs[env_to_Cenv_MAP,v_to_Cv_def] >>
    metis_tac[]) >>
  strip_tac >- (
    rw[exp_to_Cexp_def] >>
    rw[Once Cevaluate_cases]) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,v_to_Cv_def,
       exps_to_Cexps_MAP,vs_to_Cvs_MAP,
       Cevaluate_con]) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,v_to_Cv_def,
       exps_to_Cexps_MAP,Cevaluate_con]) >>
  strip_tac >- (
    fs[exp_to_Cexp_def,MEM_MAP,pairTheory.EXISTS_PROD,env_to_Cenv_MAP] >>
    rpt gen_tac >> rpt (disch_then strip_assume_tac) >> qx_gen_tac `m` >>
    fs[ALOOKUP_LEAST_EL] >>
    `find_index n (MAP FST env ++ m.bvars) 0 = find_index n (MAP FST env) 0` by (
      metis_tac[find_index_NOT_MEM,optionTheory.option_CASES,find_index_APPEND_same]  ) >>
    simp[] >>
    simp[find_index_LEAST_EL] >>
    strip_tac >>
    conj_asm1_tac >- (
      numLib.LEAST_ELIM_TAC >>
      fs[MEM_EL] >>
      conj_tac >- PROVE_TAC[] >>
      rw[] >>
      qmatch_assum_rename_tac`a < LENGTH env`[] >>
      qmatch_rename_tac`b < LENGTH env`[] >>
      `~(a<b)`by metis_tac[] >>
      DECIDE_TAC ) >>
    `(LEAST m. EL m (MAP FST env) = n) = (LEAST m. n = EL m (MAP FST env))` by (
      rw[] >> AP_TERM_TAC >> rw[FUN_EQ_THM] >> PROVE_TAC[] ) >>
    fs[EL_MAP]) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,v_to_Cv_def,env_to_Cenv_MAP,LET_THM] >>
    srw_tac[DNF_ss][Once syneq_cases] >>
    rw[FINITE_has_fresh_string,fresh_var_not_in]) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >> fs[] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    first_x_assum(qspec_then`m`mp_tac)>>simp[]>>
    disch_then(Q.X_CHOOSE_THEN`s0`mp_tac)>>
    disch_then(Q.X_CHOOSE_THEN`v0`strip_assume_tac)>>
    CONV_TAC SWAP_EXISTS_CONV >>qexists_tac`s0`>>
    CONV_TAC SWAP_EXISTS_CONV >>qexists_tac`v0`>>
    simp[] >>
    fs[do_uapp_def,LET_THM,store_alloc_def] >>
    BasicProvers.EVERY_CASE_TAC >>
    fs[v_to_Cv_def,LET_THM] >- (
      BasicProvers.VAR_EQ_TAC >>
      BasicProvers.VAR_EQ_TAC >>
      fs[v_to_Cv_def] >>
      simp[Once syneq_cases] >>
      fs[fmap_rel_def] >>
      reverse conj_asm2_tac >- (
        numLib.LEAST_ELIM_TAC >>
        qabbrev_tac`n = LENGTH s2` >>
        conj_tac >- (
          qexists_tac`SUC n` >>
          srw_tac[ARITH_ss][] ) >>
        qx_gen_tac`a` >>
        srw_tac[ARITH_ss][] >>
        Cases_on`n < a` >- (res_tac >> fs[]) >>
        DECIDE_TAC ) >>
      fs[] >>
      conj_tac >- (
        srw_tac[ARITH_ss][EXTENSION] ) >>
      simp[FAPPLY_store_to_Cstore,FAPPLY_FUPDATE_THM] >>
      fs[FAPPLY_store_to_Cstore] >>
      qx_gen_tac`x` >>
      Cases_on`x < LENGTH s2` >- (
        srw_tac[ARITH_ss][] >>
        rw[rich_listTheory.EL_APPEND1] ) >>
      strip_tac >>
      `x = LENGTH s2` by DECIDE_TAC >>
      fs[] >>
      simp[rich_listTheory.EL_LENGTH_APPEND] ) >>
    fs[Q.SPECL[`FEMPTY`,`CLoc n`]syneq_cases] >>
    rpt BasicProvers.VAR_EQ_TAC >>
    fs[fmap_rel_def,store_lookup_def] >>
    simp[FLOOKUP_DEF] >>
    BasicProvers.VAR_EQ_TAC >>
    fs[FAPPLY_store_to_Cstore] ) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM,EXISTS_PROD] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][] ) >>
  strip_tac >- (
    ntac 2 gen_tac >>
    Cases >> fs[exp_to_Cexp_def] >>
    qx_gen_tac `e1` >>
    qx_gen_tac `e2` >>
    rw[LET_THM] >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][] >>
      disj1_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >> fsrw_tac[DNF_ss][] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >> fsrw_tac[DNF_ss][] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >> fsrw_tac[DNF_ss][] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >>
      rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[] >> strip_tac >> fs[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v2) w2`[] >>
      qmatch_assum_rename_tac`SND r1 = Rval w1`[] >>
      qmatch_assum_rename_tac`SND r2 = Rval w2`[] >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva e1a r1` >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sb enva e2a r2` >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`FST r1`,`enva`,`e2a`,`r2`]mp_tac Cevaluate_any_syneq_store >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,MEM_MAP,EXISTS_PROD] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM,FORALL_PROD,MEM_MAP,EXISTS_PROD] >>
        metis_tac[] ) >>
      `free_vars FEMPTY e2a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF] >>
        simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,FST_pair,LAMBDA_PROD,FST_triple]) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`enva`,`e2a`,`r2`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      `∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        fsrw_tac[DNF_ss][EVERY_MEM] >> rw[] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        rw[] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`r1`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF] >>
        simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,FST_pair,LAMBDA_PROD,FST_triple])>>
      `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        fsrw_tac[DNF_ss][EVERY_MEM] >> rw[] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        rw[] ) >>
      simp[] >> strip_tac >> strip_tac >>
      disch_then(Q.X_CHOOSE_THEN`r3`strip_assume_tac) >>
      qmatch_assum_rename_tac`syneq FEMPTY w2 w3`[] >>
      qmatch_assum_rename_tac `do_app s3 env (Opn opn) v1 v2 = SOME (s4,env',exp'')` [] >>
      qspecl_then[`cenv`,`s'`,`env`,`e2`,`(s3,Rval v2)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[] >> strip_tac >>
      Q.ISPECL_THEN[`s3`,`s4`,`env`,`Opn opn`,`v1`,`v2`,`env'`,`exp''`]mp_tac do_app_closed >>
      simp[] >> strip_tac >> fs[] >>
      fs[do_app_Opn_SOME] >>
      rpt BasicProvers.VAR_EQ_TAC >>
      qexists_tac`FST r3` >>
      qexists_tac `w1` >>
      qexists_tac `w3` >>
      qexists_tac`FST r1` >>
      PairCases_on`r1`>>PairCases_on`r3`>>
      fs[] >> rpt BasicProvers.VAR_EQ_TAC >> fs[] >>
      PairCases_on`res`>>fs[] >>
      PairCases_on`Cres`>>fs[] >>
      PairCases_on`r2`>>fs[] >>
      fs[v_to_Cv_def,Q.SPECL[`FEMPTY`,`CLitv (IntLit x)`]syneq_cases,i0_def] >>
      rpt BasicProvers.VAR_EQ_TAC >>
      fs[v_to_Cv_def,Q.SPECL[`FEMPTY`,`CLitv (IntLit x)`]syneq_cases,i0_def] >>
      rpt BasicProvers.VAR_EQ_TAC >>
      rpt(qpat_assum`T`kall_tac) >>
      `res0 = s3` by (
        qpat_assum`evaluate cenv s3 env X Y`mp_tac >>
        BasicProvers.CASE_TAC >>
        simp[Once evaluate_cases] ) >>
      BasicProvers.VAR_EQ_TAC >>
      qabbrev_tac`sc = store_to_Cstore m res0` >>
      `fmap_rel (syneq FEMPTY) sc r30` by
        metis_tac[fmap_rel_syneq_trans] >>
      Cases_on`opn`>>fs[]>>
      fs[v_to_Cv_def,opn_lookup_def,i0_def] >>
      Cases_on`n2=0`>>fs[v_to_Cv_def] )
    >- (
      qmatch_assum_rename_tac `do_app s3 env (Opb opb) v1 v2 = SOME (s4,env',exp'')` [] >>
      fs[] >>
      qmatch_assum_rename_tac`evaluate cenv s env e1 (s1,Rval v1)`[] >>
      qmatch_assum_rename_tac`evaluate cenv s1 env e2 (s2,Rval v2)`[] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s1,Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[] >> strip_tac >>
      qspecl_then[`cenv`,`s1`,`env`,`e2`,`(s2,Rval v2)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[] >> strip_tac >>
      fs[] >>
      Q.ISPECL_THEN[`s2`,`s4`,`env`,`Opb opb`,`v1`,`v2`,`env'`,`exp''`]mp_tac do_app_closed >>
      simp[] >> strip_tac >>
      fs[] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >> rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v2) w2`[] >>
      Cases_on`Cres`>> Cases_on`Cres'`>> Cases_on`Cres''`>>fs[]>>rw[]>>
      fs[do_app_Opb_SOME]>>rw[]>>fs[v_to_Cv_def]>>rw[]>>fs[]>>rw[]>>
      fs[v_to_Cv_def]>>fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases]>>rw[]>>
      fs[exp_to_Cexp_def]>>rw[]>>
      qabbrev_tac`sa = store_to_Cstore m s` >>
      qabbrev_tac`sb = store_to_Cstore m s1` >>
      qabbrev_tac`sc = store_to_Cstore m s2` >>
      fs[]>>rw[]>>
      qmatch_assum_rename_tac`fmap_rel (syneq FEMPTY) sb sd`[]>>
      qmatch_assum_rename_tac`fmap_rel (syneq FEMPTY) sc se`[]>>
      qabbrev_tac`enva = alist_to_fmap(env_to_Cenv m env)`>>
      qabbrev_tac`e1a = exp_to_Cexp m e1`>>
      qabbrev_tac`e2a = exp_to_Cexp m e2`>>
      qabbrev_tac`w1 = CLitv (IntLit n1)`>>
      qabbrev_tac`w2 = CLitv (IntLit n2)`>>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,MEM_MAP,EXISTS_PROD] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM,EXISTS_PROD,MEM_MAP] >>
        metis_tac[] ) >>
      `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      `∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      `∀v. v ∈ FRANGE sc ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `free_vars FEMPTY e2a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`enva`,`e2a`,`(se,Rval w2)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >>
      Cases_on `opb` >> fsrw_tac[DNF_ss][EXISTS_PROD,opb_lookup_def]
      >- (
        rw[Once Cevaluate_cases] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        srw_tac[DNF_ss][] >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(se,Rval w2)`]mp_tac(Cevaluate_any_syneq_store) >>
        fsrw_tac[DNF_ss][EXISTS_PROD] >>
        qx_gen_tac`sf` >>
        qx_gen_tac`w3` >>
        strip_tac >>
        qexists_tac`sf`>>
        qexists_tac `w1` >>
        qexists_tac `w3` >>
        qexists_tac`sd`>>
        simp[] >>
        reverse conj_tac >- metis_tac[fmap_rel_syneq_trans] >>
        map_every qunabbrev_tac[`w1`,`w2`] >>
        fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] )
      >- (
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
        map_every qexists_tac [`w1`,`sd`] >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(se,Rval w2)`]mp_tac Cevaluate_any_syneq_store >>
        fsrw_tac[DNF_ss][EXISTS_PROD] >>
        qx_gen_tac`sf` >> qx_gen_tac`w3` >>
        strip_tac >>
        Q.PAT_ABBREV_TAC`fv = fresh_var X` >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sd`,`enva`,`e2a`,`(sf,Rval w3)`,`fv`,`w1`]mp_tac Cevaluate_FUPDATE >>
        `fv ∉ free_vars FEMPTY e2a` by (
          unabbrev_all_tac >>
          match_mp_tac fresh_var_not_in_any >>
          rw[] ) >>
        fsrw_tac[DNF_ss][EXISTS_PROD] >>
        qx_gen_tac`sg`>>qx_gen_tac`w4`>>
        strip_tac >>
        CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
        map_every qexists_tac [`w4`,`sg`] >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[FAPPLY_FUPDATE_THM,NOT_fresh_var] >>
        map_every qunabbrev_tac[`w1`,`w2`] >> rw[] >>
        fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >> rw[] >>
        fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >> rw[] >>
        rw[integerTheory.int_gt] >>
        metis_tac[fmap_rel_syneq_trans])
      >- (
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        srw_tac[DNF_ss][] >>
        CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
        qexists_tac`sd`>>
        qexists_tac`w2`>>
        qexists_tac`w1`>>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(se,Rval w2)`]mp_tac(Cevaluate_any_syneq_store) >>
        fsrw_tac[DNF_ss][EXISTS_PROD,Abbr`w2`,Abbr`w1`] >>
        qx_gen_tac`sf` >>
        qx_gen_tac`w3` >>
        strip_tac >>
        fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >>
        `fmap_rel (syneq FEMPTY) sc sf` by PROVE_TAC[fmap_rel_syneq_trans] >>
        qexists_tac`sf`>>
        rw[CompileTheory.i1_def] >>
        ARITH_TAC )
      >- (
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
        map_every qexists_tac [`w1`,`sd`] >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(se,Rval w2)`]mp_tac Cevaluate_any_syneq_store >>
        fsrw_tac[DNF_ss][EXISTS_PROD] >>
        qx_gen_tac`sf` >> qx_gen_tac`w3` >>
        strip_tac >>
        Q.PAT_ABBREV_TAC`fv = fresh_var X` >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sd`,`enva`,`e2a`,`(sf,Rval w3)`,`fv`,`w1`]mp_tac Cevaluate_FUPDATE >>
        `fv ∉ free_vars FEMPTY e2a` by (
          unabbrev_all_tac >>
          match_mp_tac fresh_var_not_in_any >>
          rw[] ) >>
        fsrw_tac[DNF_ss][EXISTS_PROD] >>
        qx_gen_tac`sg`>>qx_gen_tac`w4`>>
        strip_tac >>
        CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
        map_every qexists_tac [`w4`,`sg`] >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[FAPPLY_FUPDATE_THM,NOT_fresh_var] >>
        rw[Once Cevaluate_cases] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        srw_tac[DNF_ss][] >>
        rw[FAPPLY_FUPDATE_THM,NOT_fresh_var] >>
        map_every qunabbrev_tac[`w1`,`w2`] >> rw[] >>
        fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >> rw[] >>
        `fmap_rel (syneq FEMPTY) sc sg` by PROVE_TAC[fmap_rel_syneq_trans] >>
        fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >> rw[] >>
        rw[CompileTheory.i1_def] >>
        ARITH_TAC) )
    >- (
      rw[Once Cevaluate_cases] >>
      srw_tac[DNF_ss][] >>
      disj1_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      srw_tac[DNF_ss][] >>
      fs[] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac >>
      qspecl_then[`cenv`,`s'`,`env`,`e2`,`(s3,Rval v2)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac >>
      Q.ISPECL_THEN[`s3`,`s''`,`env`,`Equality`,`v1`,`v2`,`env'`,`exp''`]mp_tac do_app_closed >>
      simp[]>>strip_tac>>
      fs[] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >>
      rw[EXISTS_PROD] >>
      qmatch_assum_rename_tac `syneq FEMPTY(v_to_Cv m v1) w1`[] >>
      qmatch_assum_rename_tac `syneq FEMPTY(v_to_Cv m v2) w2`[] >>
      qabbrev_tac`sa = store_to_Cstore m s` >>
      qabbrev_tac`sb = store_to_Cstore m s'` >>
      qabbrev_tac`sc = store_to_Cstore m s3` >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva e1a X` >>
      qmatch_assum_rename_tac`Abbrev(X=(sd,Rval w1))`[]>>
      qunabbrev_tac`X` >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sb enva e2a X` >>
      qmatch_assum_rename_tac`Abbrev(X=(se,Rval w2))`[]>>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`X`]mp_tac Cevaluate_any_syneq_store >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,MEM_MAP,EXISTS_PROD] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM,EXISTS_PROD,MEM_MAP] >>
        metis_tac[] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `free_vars FEMPTY e2a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      `∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`enva`,`e2a`,`X`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[Abbr`X`] >> strip_tac >>
      fsrw_tac[DNF_ss][EXISTS_PROD,FORALL_PROD] >>
      map_every qx_gen_tac[`sf`,`w3`] >>
      strip_tac >>
      map_every qexists_tac[`sf`,`w1`,`w3`,`sd`] >>
      simp[] >>
      fs[do_app_def] >>
      rpt BasicProvers.VAR_EQ_TAC >>
      fs[] >>
      rpt BasicProvers.VAR_EQ_TAC >>
      fs[v_to_Cv_def,Q.SPECL[`c`,`CLitv l`]syneq_cases] >>
      fs[exp_to_Cexp_def] >>
      `fmap_rel (syneq FEMPTY) sc sf` by PROVE_TAC[fmap_rel_syneq_trans] >>
      cheat )
    >- (
      rw[Once Cevaluate_cases] >>
      srw_tac[DNF_ss][] >>
      disj1_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)]>>
      rw[Once(CONJUNCT2 Cevaluate_cases)]>>
      fsrw_tac[DNF_ss][] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[] >> strip_tac >>
      qspecl_then[`cenv`,`s'`,`env`,`e2`,`(s3,Rval v2)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[] >> strip_tac >>
      Q.ISPECL_THEN[`s3`,`s''`,`env`,`Opapp`,`v1`,`v2`,`env'`,`exp''`]mp_tac do_app_closed >>
      simp[] >> strip_tac >>
      fs[] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >>
      srw_tac[DNF_ss][EXISTS_PROD] >>
      qmatch_assum_rename_tac `syneq FEMPTY(v_to_Cv m v1) w1`[] >>
      qmatch_assum_rename_tac `syneq FEMPTY(v_to_Cv m v2) w2`[] >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w1)`>>
      pop_assum kall_tac >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sb enva e2a (se,Rval w2)`>>
      pop_assum kall_tac >>
      qmatch_assum_abbrev_tac`fmap_rel (syneq FEMPTY) sc se` >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(se,Rval w2)`]mp_tac Cevaluate_any_syneq_store >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,MEM_MAP,EXISTS_PROD] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM,EXISTS_PROD,MEM_MAP] >>
        metis_tac[] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `free_vars FEMPTY e2a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      `∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >>
      fsrw_tac[DNF_ss][EXISTS_PROD,FORALL_PROD] >>
      map_every qx_gen_tac[`sf`,`w3`] >>
      strip_tac >>
      CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
      qexists_tac`w3` >>
      qexists_tac`sf` >>
      `∃env1 ns' defs n. w1 = CRecClos env1 ns' defs n` by (
        imp_res_tac do_Opapp_SOME_CRecClos >> rw[] ) >>
      CONV_TAC (RESORT_EXISTS_CONV (fn ls => List.drop(ls,4)@List.take(ls,4))) >>
      map_every qexists_tac[`n`,`defs`,`ns'`,`env1`,`sd`] >>
      rw[] >>
      fs[Q.SPECL[`FEMPTY`,`CRecClos env1 ns' defs n`]Cclosed_cases] >>
      fs[MEM_EL] >> rw[] >>
      fs[do_app_Opapp_SOME] >- (
        rw[] >> fs[v_to_Cv_def,LET_THM] >>
        fs[Q.SPECL[`c`,`CRecClos env1 ns' defs zz`]syneq_cases] >>
        rw[] >> fs[] >>
        Q.PAT_ABBREV_TAC`env2 = X:string|->Cv` >>
        qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sc env3 e3a (sg,r)` >>
        ntac 2 (pop_assum kall_tac) >>
        `fmap_rel (syneq FEMPTY) sc sf` by PROVE_TAC[fmap_rel_syneq_trans] >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sc`,`sf`,`env3`,`e3a`,`(sg,r)`]mp_tac Cevaluate_any_syneq_store >>
        `free_vars FEMPTY e3a ⊆ FDOM env3` by(
          unabbrev_all_tac >> fs[] >>
          rw[env_to_Cenv_MAP,MAP_MAP_o] >>
          rw[combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair,FST_triple] ) >>
        `∀v. v ∈ FRANGE env3 ⇒ Cclosed FEMPTY v` by(
          unabbrev_all_tac >>
          fs[env_to_Cenv_MAP] >>
          match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
          fs[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
          rw[bind_def,MEM_MAP,pairTheory.EXISTS_PROD] >>
          match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
          fs[EVERY_MEM,bind_def,MEM_MAP,pairTheory.EXISTS_PROD] >>
          PROVE_TAC[]) >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sd`,`enva`,`e2a`,`(sf,Rval w3)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
        `∀v. v ∈ FRANGE sc ⇒ Cclosed FEMPTY v` by (
          unabbrev_all_tac >>
          simp[FRANGE_store_to_Cstore,MEM_MAP] >>
          fsrw_tac[DNF_ss][EVERY_MEM] >>
          PROVE_TAC[v_to_Cv_closed] ) >>
        simp[] >> strip_tac >>
        fsrw_tac[DNF_ss][EXISTS_PROD,FORALL_PROD] >>
        map_every qx_gen_tac[`sh`,`w4`]>>strip_tac>>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sf`,`env3`,`e3a`,`(sh,w4)`]mp_tac Cevaluate_free_vars_env >>
        fsrw_tac[DNF_ss][FORALL_PROD] >>
        map_every qx_gen_tac[`si`,`w5`]>>strip_tac>>
        `free_vars FEMPTY e3a ⊆ FDOM env2` by (
          unabbrev_all_tac >> fs[] ) >>
        `fmap_rel (syneq FEMPTY)
           (DRESTRICT env3 (free_vars FEMPTY e3a))
           (DRESTRICT env2 (free_vars FEMPTY e3a))` by(
          rw[fmap_rel_def,FDOM_DRESTRICT] >-
            fs[SUBSET_INTER_ABSORPTION,INTER_COMM] >>
          `x ∈ FDOM env2` by fs[SUBSET_DEF] >>
          rw[DRESTRICT_DEF] >>
          qunabbrev_tac `env3` >>
          qmatch_abbrev_tac `syneq FEMPTY (alist_to_fmap al ' x) (env2 ' x)` >>
          `∃v. ALOOKUP al x = SOME v` by (
            Cases_on `ALOOKUP al x` >> fs[] >>
            imp_res_tac ALOOKUP_FAILS >>
            unabbrev_all_tac >>
            fs[MEM_MAP,pairTheory.EXISTS_PROD] ) >>
          imp_res_tac ALOOKUP_SOME_FAPPLY_alist_to_fmap >>
          pop_assum(SUBST1_TAC) >>
          fs[Abbr`al`,env_to_Cenv_MAP,ALOOKUP_MAP] >>
          fs[bind_def] >- (
            rw[Abbr`env2`] >>
            rw[extend_rec_env_def] >>
            PROVE_TAC[syneq_trans]) >>
          rw[Abbr`env2`,extend_rec_env_def] >>
          simp[FAPPLY_FUPDATE_THM] >>
          Cases_on`n'=x` >- (
            rw[] >> PROVE_TAC[syneq_trans] ) >>
          simp[] >>
          rw[] >- (
            fs[Abbr`e3a`,NOT_fresh_var] >>
            fs[FLOOKUP_DEF,optionTheory.OPTREL_def] >>
            fsrw_tac[DNF_ss][] >>
            metis_tac[NOT_fresh_var,FINITE_FV,optionTheory.SOME_11]) >>
          fs[Abbr`e3a`] >>
          fs[FLOOKUP_DEF,optionTheory.OPTREL_def] >>
          fsrw_tac[DNF_ss][] >>
          metis_tac[NOT_fresh_var,FINITE_FV,optionTheory.SOME_11]) >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sf`,
          `DRESTRICT env3 (free_vars FEMPTY e3a)`,
          `DRESTRICT env2 (free_vars FEMPTY e3a)`,
          `e3a`,`(si,w5)`]mp_tac Cevaluate_any_syneq_env >>
        simp[FDOM_DRESTRICT] >>
        `∀v. v ∈ FRANGE env2 ⇒ Cclosed FEMPTY v` by (
          unabbrev_all_tac >>
          simp[extend_rec_env_def] >>
          fsrw_tac[DNF_ss][] >>
          match_mp_tac IN_FRANGE_DOMSUB_suff >> simp[] >>
          match_mp_tac IN_FRANGE_FUPDATE_suff >> simp[] >>
          rw[Once Cclosed_cases] ) >>
        qmatch_abbrev_tac`(P ⇒ Q) ⇒ R` >>
        `P` by (
          map_every qunabbrev_tac[`P`,`Q`,`R`] >>
          conj_tac >> match_mp_tac IN_FRANGE_DRESTRICT_suff >>
          simp[] ) >>
        simp[] >>
        map_every qunabbrev_tac[`P`,`Q`,`R`] >>
        pop_assum kall_tac >>
        fsrw_tac[DNF_ss][FORALL_PROD] >>
        map_every qx_gen_tac [`sj`,`w6`] >>
        strip_tac >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sf`,`env2`,`e3a`,`(sj,w6)`]mp_tac Cevaluate_any_super_env >>
        fsrw_tac[DNF_ss][EXISTS_PROD] >>
        map_every qx_gen_tac [`sk`,`w7`] >>
        strip_tac >>
        map_every qexists_tac[`w7`,`sk`] >>
        simp[] >>
        PROVE_TAC[fmap_rel_syneq_trans,result_rel_syneq_trans] ) >>
      rw[] >>
      fs[v_to_Cv_def,LET_THM,defs_to_Cdefs_MAP] >>
      fs[Q.SPECL[`c`,`CRecClos env1 ns' defs X`]syneq_cases] >>
      rw[] >> fs[] >> rw[] >> rfs[] >> rw[] >>
      PairCases_on`z`>>fs[]>>rw[]>>
      qpat_assum `X < LENGTH Y` assume_tac >>
      fs[EL_MAP] >>
      qmatch_assum_rename_tac `ALL_DISTINCT (MAP FST ns)`[] >>
      qabbrev_tac`q = EL n' ns` >>
      PairCases_on `q` >>
      pop_assum (mp_tac o SYM o SIMP_RULE std_ss [markerTheory.Abbrev_def]) >> rw[] >>
      fs[] >> rw[] >>
      `ALOOKUP ns q0 = SOME (q1,q2,q3,q4)` by (
        match_mp_tac ALOOKUP_ALL_DISTINCT_MEM >>
        rw[MEM_EL] >> PROVE_TAC[] ) >>
      fs[] >> rw[] >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sc env3 ee r` >>
      qmatch_assum_rename_tac`Abbrev(r=(sg,w4))`[]>>
      qmatch_assum_rename_tac`EL n' ns = (q0,q1,q2,q3,q4)`[]>>
      Q.PAT_ABBREV_TAC`env2 = X:string|->Cv` >>
      qmatch_assum_abbrev_tac `result_rel (syneq FEMPTY) rr w4` >>
      fs[Q.SPEC`Recclosure l ns q0`closed_cases] >>
      `free_vars FEMPTY ee ⊆ FDOM env2` by (
        first_x_assum (qspecl_then [`n'`,`[q2]`,`INL ee`] mp_tac) >>
        unabbrev_all_tac >> fs[] >>
        rw[EL_MAP] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sd`,`enva`,`e2a`,`(sf,Rval w3)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >>
      `∀v. v ∈ FRANGE env2 ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >> fs[] >>
        fs[extend_rec_env_def] >>
        qx_gen_tac `v` >>
        Cases_on `v=w3` >> fs[] >>
        match_mp_tac IN_FRANGE_DOMSUB_suff >>
        fs[FOLDL_FUPDATE_LIST] >>
        match_mp_tac IN_FRANGE_FUPDATE_LIST_suff >> fs[] >>
        fs[MAP_MAP_o,MEM_MAP,pairTheory.EXISTS_PROD] >>
        fsrw_tac[DNF_ss][] >>
        rw[Once Cclosed_cases,MEM_MAP,pairTheory.EXISTS_PROD]
          >- PROVE_TAC[]
          >- ( first_x_assum match_mp_tac >>
               PROVE_TAC[] ) >>
        Cases_on `cb` >> fs[] >>
        pop_assum mp_tac >>
        fs[EL_MAP,pairTheory.UNCURRY]) >>
      `fmap_rel (syneq FEMPTY) sc sf` by metis_tac[fmap_rel_syneq_trans] >>
      `∀v. v ∈ FRANGE env3 ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        simp[env_to_Cenv_MAP,build_rec_env_MAP,MAP_MAP_o,bind_def,MEM_MAP,EXISTS_PROD] >>
        fsrw_tac[DNF_ss][] >>
        conj_tac >- (
          match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> rw[] ) >>
        conj_tac >- (
          rpt gen_tac >> strip_tac >>
          match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
          rw[Once closed_cases,MEM_MAP,EXISTS_PROD] >>
          metis_tac[] ) >>
        rpt gen_tac >> strip_tac >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM,build_rec_env_MAP,MEM_MAP,EXISTS_PROD,bind_def] >>
        metis_tac[] ) >>
      `free_vars FEMPTY ee ⊆ FDOM env3` by (
        unabbrev_all_tac >> fs[] >>
        rw[env_to_Cenv_MAP,MAP_MAP_o] >>
        rw[combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair,FST_triple] ) >>
      `∀v. v ∈ FRANGE sc ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        fsrw_tac[DNF_ss][FORALL_PROD] >> rw[] >>
        fs[EVERY_MEM] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        PROVE_TAC[] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sc`,`sf`,`env3`,`ee`,`r`]mp_tac Cevaluate_any_syneq_store >>
      fsrw_tac[DNF_ss][FORALL_PROD,Abbr`r`] >>
      `fmap_rel (syneq FEMPTY)
         (DRESTRICT env3 (free_vars FEMPTY ee))
         (DRESTRICT env2 (free_vars FEMPTY ee))` by (
        rw[fmap_rel_def,FDOM_DRESTRICT] >-
          fs[SUBSET_INTER_ABSORPTION,INTER_COMM] >>
        `x ∈ FDOM env2` by fs[SUBSET_DEF] >>
        rw[DRESTRICT_DEF] >>
        qunabbrev_tac `env3` >>
        qmatch_abbrev_tac `syneq FEMPTY (alist_to_fmap al ' x) (env2 ' x)` >>
        `∃v. ALOOKUP al x = SOME v` by (
          Cases_on `ALOOKUP al x` >> fs[] >>
          imp_res_tac ALOOKUP_FAILS >>
          unabbrev_all_tac >>
          fs[MEM_MAP,pairTheory.EXISTS_PROD] ) >>
        imp_res_tac ALOOKUP_SOME_FAPPLY_alist_to_fmap >>
        qpat_assum `alist_to_fmap al ' x = X`(SUBST1_TAC) >>
        fs[Abbr`al`,env_to_Cenv_MAP,ALOOKUP_MAP] >> rw[] >>
        fs[bind_def] >- (
          rw[Abbr`env2`] >>
          rw[extend_rec_env_def] >>
          PROVE_TAC[syneq_trans]) >>
        Cases_on `q2=x`>>fs[] >- (
          rw[] >>
          rw[Abbr`env2`,extend_rec_env_def] >>
          PROVE_TAC[syneq_trans]) >>
        qpat_assum `ALOOKUP X Y = SOME Z` mp_tac >>
        asm_simp_tac(srw_ss())[build_rec_env_def,bind_def,FOLDR_CONS_5tup] >>
        rw[ALOOKUP_APPEND] >>
        Cases_on `MEM x (MAP FST ns)` >>
        fs[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair,FST_triple] >- (
          qpat_assum `X = SOME v'` mp_tac >>
          qho_match_abbrev_tac `((case ALOOKUP (MAP ff ns) x of
            NONE => ALOOKUP (MAP fg env'') x | SOME v => SOME v) = SOME v') ⇒ P` >>
          `MAP FST (MAP ff ns) = MAP FST ns` by (
            asm_simp_tac(srw_ss())[LIST_EQ_REWRITE,Abbr`ff`] >>
            qx_gen_tac `y` >> strip_tac >>
            fs[MAP_MAP_o,combinTheory.o_DEF,EL_MAP] >>
            qabbrev_tac `yy = EL y ns` >>
            PairCases_on `yy` >> fs[] ) >>
          `ALL_DISTINCT (MAP FST (MAP ff ns))` by PROVE_TAC[] >>
          `MEM (x,v_to_Cv m (Recclosure env'' ns x)) (MAP ff ns)` by (
            rw[Abbr`ff`,MEM_MAP,pairTheory.EXISTS_PROD] >>
            fs[MEM_MAP,pairTheory.EXISTS_PROD,MAP_MAP_o,combinTheory.o_DEF,UNCURRY] >>
            PROVE_TAC[] ) >>
          imp_res_tac ALOOKUP_ALL_DISTINCT_MEM >>
          fs[] >> rw[Abbr`P`] >>
          rw[v_to_Cv_def] >>
          rw[Abbr`env2`,extend_rec_env_def,FOLDL_FUPDATE_LIST] >>
          rw[FAPPLY_FUPDATE_THM] >>
          ho_match_mp_tac FUPDATE_LIST_ALL_DISTINCT_APPLY_MEM >>
          fs[MAP_MAP_o,combinTheory.o_DEF] >>
          fsrw_tac[ETA_ss][] >>
          fs[pairTheory.LAMBDA_PROD] >>
          fsrw_tac[DNF_ss][MEM_MAP,pairTheory.EXISTS_PROD] >>
          rw[Once syneq_cases] >>
          fs[defs_to_Cdefs_MAP] >>
          qmatch_assum_rename_tac `MEM (x,z0,z1,z2,z3) ns`[] >>
          map_every qexists_tac [`z0`,`z1`,`z2`,`z3`] >> fs[] >>
          rw[] >>
          fs[EVERY_MEM,pairTheory.FORALL_PROD] >>
          fs[MEM_MAP,pairTheory.EXISTS_PROD] >>
          fsrw_tac[DNF_ss][] >>
          fs[env_to_Cenv_MAP,ALOOKUP_MAP] >>
          fsrw_tac[ETA_ss][] >>
          fs[Abbr`Cenv`] >>
          fs[ALOOKUP_MAP] >>
          fsrw_tac[ETA_ss][] >>
          metis_tac[]) >>
        qpat_assum `X = SOME v'` mp_tac >>
        qho_match_abbrev_tac `((case ALOOKUP (MAP ff ns) x of
          NONE => ALOOKUP (MAP fg env'') x | SOME v => SOME v) = SOME v') ⇒ P` >>
        `MAP FST (MAP ff ns) = MAP FST ns` by (
          asm_simp_tac(srw_ss())[LIST_EQ_REWRITE,Abbr`ff`] >>
          qx_gen_tac `y` >> strip_tac >>
          fs[MAP_MAP_o,combinTheory.o_DEF,EL_MAP] >>
          qabbrev_tac `yy = EL y ns` >>
          PairCases_on `yy` >> fs[] ) >>
        `ALOOKUP (MAP ff ns) x= NONE` by (
          rw[ALOOKUP_NONE]) >>
        rw[Abbr`P`] >>
        rw[Abbr`env2`] >>
        rw[extend_rec_env_def,FOLDL_FUPDATE_LIST] >>
        rw[FAPPLY_FUPDATE_THM] >>
        ho_match_mp_tac FUPDATE_LIST_APPLY_HO_THM >>
        disj2_tac >>
        fs[MAP_MAP_o,combinTheory.o_DEF] >>
        fsrw_tac[ETA_ss][] >>
        fsrw_tac[DNF_ss][EVERY_MEM,pairTheory.FORALL_PROD] >>
        fsrw_tac[DNF_ss][optionTheory.OPTREL_def,FLOOKUP_DEF] >>
        fsrw_tac[DNF_ss][MEM_MAP,pairTheory.EXISTS_PROD] >>
        fs[Abbr`ee`] >>
        imp_res_tac ALOOKUP_MEM >>
        metis_tac[NOT_fresh_var,FINITE_FV,optionTheory.SOME_11] ) >>
      map_every qx_gen_tac[`sh`,`w5`] >> strip_tac >>
      qspecl_then [`FEMPTY`,`FEMPTY`,`sf`,`env3`,`ee`,`(sh,w5)`] mp_tac Cevaluate_free_vars_env >>
      simp[] >>
      fsrw_tac[DNF_ss][FORALL_PROD] >>
      map_every qx_gen_tac[`si`,`w6`] >> strip_tac >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sf`,
        `DRESTRICT env3 (free_vars FEMPTY ee)`,
        `DRESTRICT env2 (free_vars FEMPTY ee)`,
        `ee`,`(si,w6)`]mp_tac Cevaluate_any_syneq_env >>
      simp[FDOM_DRESTRICT] >>
      qmatch_abbrev_tac`(P ⇒ Q) ⇒ R` >>
      `P` by (
        map_every qunabbrev_tac[`P`,`Q`,`R`] >>
        conj_tac >> match_mp_tac IN_FRANGE_DRESTRICT_suff >>
        simp[] ) >>
      simp[] >>
      map_every qunabbrev_tac[`P`,`Q`,`R`] >>
      pop_assum kall_tac >>
      fsrw_tac[DNF_ss][FORALL_PROD] >>
      map_every qx_gen_tac [`sj`,`w7`] >>
      strip_tac >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sf`,`env2`,`ee`,`(sj,w7)`]mp_tac Cevaluate_any_super_env >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      map_every qx_gen_tac [`sk`,`w8`] >>
      strip_tac >>
      map_every qexists_tac[`w8`,`sk`] >>
      simp[] >>
      PROVE_TAC[fmap_rel_syneq_trans,result_rel_syneq_trans] )
    >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][] >>
      disj1_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      fsrw_tac[DNF_ss][] >>
      fs[do_app_def] >>
      Cases_on`v1`>>fs[] >>
      Cases_on`store_assign n v2 s3`>>fs[] >>
      rw[] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval (Loc n))`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac >> fs[] >>
      fs[store_assign_def] >> rw[] >> fs[] >> rw[] >>
      qspecl_then[`cenv`,`s'`,`env`,`e2`,`(s3,Rval v2)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac >>
      `EVERY closed (LUPDATE v2 n s3)` by (
        fs[EVERY_MEM] >>
        metis_tac[MEM_LUPDATE] ) >>
      fs[] >>
      rpt (first_x_assum (qspec_then`m`mp_tac)) >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >> rw[] >>
      fs[v_to_Cv_def,exp_to_Cexp_def] >>
      rw[] >> fs[] >> rw[] >>
      fs[Q.SPECL[`FEMPTY`,`CLoc n`]syneq_cases] >> rw[] >>
      CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`CLoc n` >> rw[] >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval (CLoc n))` >>
      pop_assum kall_tac >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sb enva e2a (se,w1)` >>
      qpat_assum`Abbrev (se  = X)`kall_tac >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(se,w1)`]mp_tac Cevaluate_any_syneq_store >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,MEM_MAP,EXISTS_PROD] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM,EXISTS_PROD,MEM_MAP] >>
        metis_tac[] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `free_vars FEMPTY e2a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      `∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval (CLoc n))`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >>
      fsrw_tac[DNF_ss][FORALL_PROD] >>
      map_every qx_gen_tac[`sf`,`w2`] >>
      strip_tac >>
      fs[Abbr`w1`] >> rw[] >>
      qmatch_assum_rename_tac`syneq FEMPTY w1 w2`[] >>
      map_every qexists_tac[`sf`,`w2`,`sd`] >>
      simp[] >>
      fs[fmap_rel_def] >>
      conj_tac >- (rw[EXTENSION] >> PROVE_TAC[]) >>
      rw[FAPPLY_FUPDATE_THM,FAPPLY_store_to_Cstore,EL_LUPDATE] >-
        PROVE_TAC[syneq_trans] >>
      fs[FAPPLY_store_to_Cstore,EXTENSION] >>
      PROVE_TAC[syneq_trans])) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    ntac 2 gen_tac >>
    Cases >> fs[exp_to_Cexp_def] >>
    qx_gen_tac `e1` >>
    qx_gen_tac `e2` >>
    rw[LET_THM] >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      disj2_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      fsrw_tac[DNF_ss][] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[] >> strip_tac >> fs[] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >>
      rw[] >>
      disj2_tac >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sb enva e2a (sc,Rerr err)`>>
      pop_assum kall_tac >>
      qmatch_assum_rename_tac `fmap_rel (syneq FEMPTY) sb sd`[] >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(sc,Rerr err)`]mp_tac Cevaluate_any_syneq_store >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w1)`>>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EVERY_MEM,EXISTS_PROD,FORALL_PROD] >>
        rw[] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        PROVE_TAC[]) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `free_vars FEMPTY e2a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
        rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> PROVE_TAC[] ) >>
      `∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
        rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> PROVE_TAC[] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >>
      fsrw_tac[DNF_ss][FORALL_PROD] >>
      qx_gen_tac`se` >> strip_tac >>
      map_every qexists_tac [`se`,`sd`,`w1`] >> fs[] >>
      PROVE_TAC[fmap_rel_syneq_trans])
    >- (
      fs[] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac>>fs[]>>
      fsrw_tac[DNF_ss][EXISTS_PROD]>>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >>
      rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w1)` >>
      pop_assum kall_tac >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sb enva e2a (sc,Rerr err)` >>
      pop_assum kall_tac >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        imp_res_tac v_to_Cv_closed >>
        fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva ∧
       free_vars FEMPTY e2a ⊆ FDOM enva` by (
        fs[Abbr`e1a`,Abbr`e2a`,Abbr`enva`,env_to_Cenv_MAP,MAP_MAP_o,
           pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair,FST_triple] ) >>
      `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
       (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
         unabbrev_all_tac >>
         fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
         rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >> fs[] >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(sc,Rerr err)`]mp_tac Cevaluate_any_syneq_store >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      qx_gen_tac`se`>>strip_tac >>
      `fmap_rel (syneq FEMPTY) (store_to_Cstore m s3) se` by PROVE_TAC[fmap_rel_syneq_trans] >>
      BasicProvers.EVERY_CASE_TAC >>
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][]
      >- (
        disj2_tac >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        srw_tac[DNF_ss][] >>
        disj2_tac >>
        metis_tac[])
      >- (
        disj1_tac >>
        CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
        map_every qexists_tac[`w1`,`sd`] >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        disj2_tac >>
        Q.PAT_ABBREV_TAC`fv = fresh_var X` >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sd`,`enva`,`e2a`,`se`,`err`,`fv`,`w1`]mp_tac Cevaluate_FUPDATE_Rerr >>
        `fv ∉ free_vars FEMPTY e2a` by (
          unabbrev_all_tac >>
          match_mp_tac fresh_var_not_in_any >>
          rw[] ) >>
        simp[] >>
        PROVE_TAC[fmap_rel_syneq_trans])
      >- (
        disj2_tac >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        disj2_tac >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        srw_tac[DNF_ss][] >>
        disj2_tac >>
        PROVE_TAC[] )
      >- (
        disj1_tac >>
        CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
        map_every qexists_tac[`w1`,`sd`] >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        disj2_tac >>
        Q.PAT_ABBREV_TAC`fv = fresh_var X` >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sd`,`enva`,`e2a`,`se`,`err`,`fv`,`w1`]mp_tac Cevaluate_FUPDATE_Rerr >>
        `fv ∉ free_vars FEMPTY e2a` by (
          unabbrev_all_tac >>
          match_mp_tac fresh_var_not_in_any >>
          rw[] ) >>
        simp[] >>
        PROVE_TAC[fmap_rel_syneq_trans]))
    >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      disj2_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      srw_tac[DNF_ss][]>>
      disj2_tac >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac>>fs[]>>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >> rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w1)` >>
      pop_assum kall_tac >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sb enva e2a (sc,Rerr err)` >>
      pop_assum kall_tac >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        imp_res_tac v_to_Cv_closed >>
        fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva ∧
       free_vars FEMPTY e2a ⊆ FDOM enva` by (
        fs[Abbr`e1a`,Abbr`e2a`,Abbr`enva`,env_to_Cenv_MAP,MAP_MAP_o,
           pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair,FST_triple] ) >>
      `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
       (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
         unabbrev_all_tac >>
         fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
         rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >> fs[] >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(sc,Rerr err)`]mp_tac Cevaluate_any_syneq_store >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      qx_gen_tac`se`>>strip_tac >>
      PROVE_TAC[fmap_rel_syneq_trans] )
    >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][] >>
      disj2_tac >> disj1_tac >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac>>fs[]>>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >> rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w1)` >>
      pop_assum kall_tac >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sb enva e2a (sc,Rerr err)` >>
      pop_assum kall_tac >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        imp_res_tac v_to_Cv_closed >>
        fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva ∧
       free_vars FEMPTY e2a ⊆ FDOM enva` by (
        fs[Abbr`e1a`,Abbr`e2a`,Abbr`enva`,env_to_Cenv_MAP,MAP_MAP_o,
           pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair,FST_triple] ) >>
      `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
       (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
         unabbrev_all_tac >>
         fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
         rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >> fs[] >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(sc,Rerr err)`]mp_tac Cevaluate_any_syneq_store >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      PROVE_TAC[fmap_rel_syneq_trans])
    >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      disj2_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      srw_tac[DNF_ss][] >>
      disj2_tac >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac>>fs[]>>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >> rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w1)` >>
      pop_assum kall_tac >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sb enva e2a (sc,Rerr err)` >>
      pop_assum kall_tac >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        imp_res_tac v_to_Cv_closed >>
        fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva ∧
       free_vars FEMPTY e2a ⊆ FDOM enva` by (
        fs[Abbr`e1a`,Abbr`e2a`,Abbr`enva`,env_to_Cenv_MAP,MAP_MAP_o,
           pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair,FST_triple] ) >>
      `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
       (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
         unabbrev_all_tac >>
         fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
         rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >> fs[] >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(sc,Rerr err)`]mp_tac Cevaluate_any_syneq_store >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      PROVE_TAC[fmap_rel_syneq_trans])) >>
  strip_tac >- (
    ntac 2 gen_tac >>
    Cases >> fs[exp_to_Cexp_def] >>
    qx_gen_tac `e1` >>
    qx_gen_tac `e2` >>
    rw[LET_THM] >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      disj2_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      fsrw_tac[DNF_ss][])
    >- (
      BasicProvers.EVERY_CASE_TAC >>
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      fsrw_tac[DNF_ss][] >>
      disj2_tac >- (
        rw[Once(CONJUNCT2 Cevaluate_cases)] >>
        fsrw_tac[DNF_ss][] ) >>
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][] >>
      disj1_tac >>
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][] >>
      disj2_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      fsrw_tac[DNF_ss][])
    >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      disj2_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      fsrw_tac[DNF_ss][])
    >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD])
    >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      disj2_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      fsrw_tac[DNF_ss][]) ) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    imp_res_tac do_log_FV >>
    `FV exp' ⊆ set (MAP FST env)` by PROVE_TAC[SUBSET_TRANS] >>
    qspecl_then[`cenv`,`s`,`env`,`exp`,`(s',Rval v)`]mp_tac(CONJUNCT1 evaluate_closed) >>
    simp[]>>strip_tac>>fs[]>>
    rpt (first_x_assum (qspec_then`m` mp_tac)) >> rw[] >>
    qmatch_assum_rename_tac`syneq FEMPTY (v_to_Cv m v) w`[] >>
    qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w)` >>
    pop_assum kall_tac >>
    qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sb enva e2a (sc,w2)` >>
    ntac 2 (pop_assum kall_tac) >>
    `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
      imp_res_tac v_to_Cv_closed >>
      fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
    `free_vars FEMPTY e1a ⊆ FDOM enva ∧
     free_vars FEMPTY e2a ⊆ FDOM enva` by (
      fs[Abbr`e1a`,Abbr`e2a`,Abbr`enva`,env_to_Cenv_MAP,MAP_MAP_o,
         pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair,FST_triple] ) >>
    `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
     (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
       unabbrev_all_tac >>
       fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
       rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
    simp[] >> strip_tac >> fs[] >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(sc,w2)`]mp_tac Cevaluate_any_syneq_store >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    map_every qx_gen_tac[`se`,`w3`] >>strip_tac >>
    Cases_on `op` >> Cases_on `v` >> fs[do_log_def] >>
    Cases_on `l` >> fs[v_to_Cv_def] >>
    fs[Q.SPECL[`c`,`CLitv l`]syneq_cases] >> rw[] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][] >> disj1_tac >>
    CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
    map_every qexists_tac [`b`,`sd`] >> fs[] >>
    rw[] >> fs[] >> rw[] >>
    fs[evaluate_lit] >> rw[v_to_Cv_def] >>
    PROVE_TAC[result_rel_syneq_trans,fmap_rel_syneq_trans] ) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    Cases_on `op` >> fsrw_tac[DNF_ss][] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD]) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    imp_res_tac do_if_FV >>
    `FV exp' ⊆ set (MAP FST env)` by (
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      PROVE_TAC[]) >> fs[] >>
    qspecl_then[`cenv`,`s`,`env`,`exp`,`(s',Rval v)`]mp_tac(CONJUNCT1 evaluate_closed) >>
    simp[]>>strip_tac>>fs[]>>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][] >>
    disj1_tac >>
    rpt (first_x_assum (qspec_then`m` mp_tac)) >> rw[] >>
    qmatch_assum_rename_tac`syneq FEMPTY (v_to_Cv m v) w`[] >>
    qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w)` >>
    pop_assum kall_tac >>
    qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sb enva e2a (sc,w2)` >>
    ntac 2 (pop_assum kall_tac) >>
    `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
      imp_res_tac v_to_Cv_closed >>
      fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
    `free_vars FEMPTY e1a ⊆ FDOM enva ∧
     free_vars FEMPTY e2a ⊆ FDOM enva` by (
      fs[Abbr`e1a`,Abbr`e2a`,Abbr`enva`,env_to_Cenv_MAP,MAP_MAP_o,
         pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair,FST_triple] ) >>
    `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
     (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
       unabbrev_all_tac >>
       fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
       rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
    simp[] >> strip_tac >> fs[] >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(sc,w2)`]mp_tac Cevaluate_any_syneq_store >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    map_every qx_gen_tac[`se`,`w3`] >>strip_tac >>
    CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
    CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`sd` >>
    CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`w3` >>
    CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`se` >>
    qpat_assum `do_if v e2 e3 = X` mp_tac >>
    fs[do_if_def] >> rw[] >|[
      qexists_tac`T`,
      qexists_tac`F`] >>
    fsrw_tac[DNF_ss][v_to_Cv_def,Q.SPECL[`c`,`CLitv l`]syneq_cases] >>
    PROVE_TAC[fmap_rel_syneq_trans,result_rel_syneq_trans]) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >> fs[] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD]) >>
  strip_tac >- (
    rpt strip_tac >> fs[] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    first_x_assum (qspec_then `m` mp_tac) >> rw[] >>
    qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v) w`[] >>
    rw[exp_to_Cexp_def,LET_THM] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][] >>
    disj1_tac >>
    qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva ea (sd,Rval w)` >>
    pop_assum kall_tac >>
    CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
    map_every qexists_tac [`w`,`sd`] >> fs[] >>
    qmatch_assum_abbrev_tac `evaluate_match_with P cenv s2 env v pes res` >>
    Q.ISPECL_THEN [`s2`,`pes`,`res`] mp_tac (Q.GEN`s`evaluate_match_with_matchres) >> fs[] >>
    PairCases_on`res`>>fs[]>>strip_tac>>
    qmatch_assum_abbrev_tac`evaluate_match_with (matchres env) cenv s2 env v pes r` >>
    Q.ISPECL_THEN [`s2`,`pes`,`r`] mp_tac (Q.GEN`s`evaluate_match_with_Cevaluate_match) >>
    fs[Abbr`r`] >>
    disch_then (qspec_then `m` mp_tac) >>
    rw[] >- (
      qmatch_assum_abbrev_tac `Cevaluate_match sb vv ppes FEMPTY NONE` >>
      `Cevaluate_match sb vv (MAP (λ(p,e). (p, exp_to_Cexp m e)) ppes) FEMPTY NONE` by (
        metis_tac [Cevaluate_match_MAP_exp, optionTheory.OPTION_MAP_DEF] ) >>
      qmatch_assum_abbrev_tac `Cevaluate_match sb vv (MAP ff ppes) FEMPTY NONE` >>
      `MAP ff ppes = pes_to_Cpes m pes` by (
        unabbrev_all_tac >>
        rw[pes_to_Cpes_MAP,LET_THM] >>
        rw[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
        rw[pairTheory.UNCURRY] ) >>
      fs[] >>
      map_every qunabbrev_tac[`ppes`,`ff`,`vv`] >>
      pop_assum kall_tac >>
      ntac 2 (pop_assum mp_tac) >>
      pop_assum kall_tac >>
      ntac 2 strip_tac >>
      Q.SPECL_THEN [`sb`,`v_to_Cv m v`,`pes_to_Cpes m pes`,`FEMPTY`,`NONE`]
        mp_tac (INST_TYPE[alpha|->``:Cexp``](Q.GENL[`v`,`s`] Cevaluate_match_syneq)) >>
      fs[] >>
      disch_then (qspecl_then [`FEMPTY`,`sd`,`w`] mp_tac) >> fs[] >>
      strip_tac >>
      qabbrev_tac`ps = pes_to_Cpes m pes` >>
      qspecl_then[`sd`,`w`,`ps`,`FEMPTY`,`NONE`]mp_tac(Q.GENL[`v`,`s`]Cevaluate_match_remove_mat_var)>>
      fs[] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      Q.PAT_ABBREV_TAC`envu = enva |+ X` >>
      Q.PAT_ABBREV_TAC`fv = fresh_var X` >>
      disch_then (qspecl_then[`envu`,`fv`]mp_tac)>>
      qmatch_abbrev_tac`(P0 ⇒ Q) ⇒ R` >>
      `P0` by (
        map_every qunabbrev_tac[`P0`,`Q`,`R`] >>
        fs[FLOOKUP_UPDATE,Abbr`envu`] >>
        fsrw_tac[DNF_ss][pairTheory.FORALL_PROD] >>
        conj_tac >- (
          qx_gen_tac `z` >>
          Cases_on `fv ∈ z` >> fs[] >>
          qx_gen_tac `p` >>
          qx_gen_tac `e` >>
          Cases_on `z = Cpat_vars p` >> fs[] >>
          spose_not_then strip_assume_tac >>
          `fv ∉ Cpat_vars p` by (
            unabbrev_all_tac >>
            match_mp_tac fresh_var_not_in_any >>
            rw[Cpes_vars_thm] >> rw[] >>
            srw_tac[DNF_ss][SUBSET_DEF,pairTheory.EXISTS_PROD,MEM_MAP] >>
            metis_tac[] ) ) >>
        conj_tac >- (
          unabbrev_all_tac >>
          fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair,FST_triple] >>
          fsrw_tac[DNF_ss][SUBSET_DEF,pairTheory.FORALL_PROD,pes_to_Cpes_MAP,MEM_MAP,LET_THM,pairTheory.EXISTS_PROD] >>
          fsrw_tac[DNF_ss][pairTheory.UNCURRY,Cpes_vars_thm] >>
          metis_tac[Cpat_vars_pat_to_Cpat,pairTheory.pair_CASES,pairTheory.SND] ) >>
        `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
          unabbrev_all_tac >>
          fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
          rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
        `free_vars FEMPTY ea ⊆ FDOM enva` by (
          unabbrev_all_tac >>
          fs[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,LAMBDA_PROD,FST_pair,FST_triple]) >>
        `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
          unabbrev_all_tac >>
          match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
          fsrw_tac[DNF_ss][MEM_MAP,FORALL_PROD,env_to_Cenv_MAP,EVERY_MEM] >>
          rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`ea`,`(sd,Rval w)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
        simp[] >> strip_tac >>
        match_mp_tac IN_FRANGE_DOMSUB_suff >>
        rw[] ) >>
      simp[] >>
      map_every qunabbrev_tac[`P0`,`Q`,`R`] >>
      metis_tac[fmap_rel_syneq_trans,fmap_rel_syneq_sym] ) >>
    qmatch_assum_abbrev_tac `Cevaluate_match sb vv ppes eenv (SOME mr)` >>
    `Cevaluate_match sb vv (MAP (λ(p,e). (p, exp_to_Cexp m e)) ppes) eenv (SOME (exp_to_Cexp m mr))` by (
      metis_tac [Cevaluate_match_MAP_exp, optionTheory.OPTION_MAP_DEF] ) >>
    pop_assum mp_tac >>
    map_every qunabbrev_tac[`ppes`,`eenv`,`vv`] >>
    pop_assum mp_tac >>
    pop_assum kall_tac >>
    ntac 2 strip_tac >>
    qmatch_assum_abbrev_tac `Cevaluate_match sb vv (MAP ff ppes) eenv mmr` >>
    `MAP ff ppes = pes_to_Cpes m pes` by (
      unabbrev_all_tac >>
      rw[pes_to_Cpes_MAP,LET_THM] >>
      rw[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
      rw[pairTheory.UNCURRY] ) >>
    fs[] >>
    pop_assum kall_tac >>
    qunabbrev_tac `ppes` >>
    qabbrev_tac`ps = pes_to_Cpes m pes` >>
    Q.ISPECL_THEN[`sb`,`vv`,`ps`,`eenv`,`mmr`]mp_tac(Q.GENL[`v`,`s`]Cevaluate_match_syneq) >>
    simp[] >>
    disch_then(qspecl_then[`FEMPTY`,`sd`,`w`]mp_tac) >>
    simp[] >>
    disch_then(Q.X_CHOOSE_THEN`wenv`strip_assume_tac) >>
    qspecl_then[`sd`,`w`,`ps`,`wenv`,`mmr`]mp_tac(Q.GENL[`v`,`s`]Cevaluate_match_remove_mat_var) >>
    simp[Abbr`mmr`] >>
    Q.PAT_ABBREV_TAC`fv = fresh_var X` >>
    fsrw_tac[DNF_ss][FORALL_PROD,EXISTS_PROD] >>
    disch_then(qspecl_then[`enva|+(fv,w)`,`fv`]mp_tac) >>
    qspecl_then[`cenv`,`s`,`env`,`exp`,`(s2,Rval v)`]mp_tac(CONJUNCT1 evaluate_closed) >>
    simp[] >> strip_tac >>
    Q.ISPECL_THEN[`s2`,`pes`,`(s2,Rval(menv,mr))`]mp_tac(Q.GEN`s`evaluate_match_with_matchres_closed)>>
    simp[] >> strip_tac >>
    `FV mr ⊆ set (MAP FST (menv ++ env))` by (
      fsrw_tac[DNF_ss][SUBSET_DEF,FORALL_PROD,MEM_MAP,EXISTS_PROD] >>
      pop_assum mp_tac >>
      simp[EXTENSION] >>
      fsrw_tac[DNF_ss][MEM_MAP,EXISTS_PROD] >>
      METIS_TAC[] ) >>
    fs[Abbr`P`] >> rfs[] >> fs[] >>
    first_x_assum(qspec_then`m`mp_tac)>>
    fsrw_tac[DNF_ss][] >>
    qpat_assum`evaluate_match_with P cenv s2 env v pes (res0,res1)`kall_tac >>
    map_every qx_gen_tac [`se`,`re`] >> strip_tac >>
    qabbrev_tac`emr = exp_to_Cexp m mr` >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`eenv ⊌ enva`,`wenv ⊌ enva`,`emr`,`(se,re)`]mp_tac Cevaluate_any_syneq_any >>
    `∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
      rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
    `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >>
      match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
      fsrw_tac[DNF_ss][env_to_Cenv_MAP,MEM_MAP,FORALL_PROD,EVERY_MEM] >>
      rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
    `free_vars FEMPTY ea ⊆ FDOM enva` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][env_to_Cenv_MAP,SUBSET_DEF,MEM_MAP,FORALL_PROD,EXISTS_PROD]) >>
    `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
      rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`ea`,`(sd,Rval w)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
    simp[] >> strip_tac >>
    qspecl_then[`FEMPTY`,`sd`,`w`,`ps`,`wenv`,`SOME emr`]mp_tac
      (INST_TYPE[alpha|->``:Cexp``](Q.GENL[`v`,`s`,`c`]Cevaluate_match_closed)) >>
    simp[] >> strip_tac >>
    `∀v. v ∈ FRANGE eenv ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >>
      match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
      fsrw_tac[DNF_ss][env_to_Cenv_MAP,MEM_MAP,EVERY_MEM,FORALL_PROD,EXISTS_PROD] >>
      rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
    qmatch_abbrev_tac`(P ⇒ Q) ⇒ R` >>
    `P` by (
      map_every qunabbrev_tac[`P`,`Q`,`R`] >>
      conj_tac >- (
        match_mp_tac fmap_rel_FUNION_rels >> rw[] ) >>
      conj_tac >- (
        match_mp_tac IN_FRANGE_FUNION_suff >> rw[] ) >>
      conj_tac >- (
        unabbrev_all_tac >>
        rw[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,UNCURRY] >>
        srw_tac[ETA_ss][] ) >>
      match_mp_tac IN_FRANGE_FUNION_suff >> rw[] ) >>
    simp[] >>
    map_every qunabbrev_tac[`P`,`Q`,`R`] >>
    fsrw_tac[DNF_ss][FORALL_PROD] >>
    map_every qx_gen_tac[`sf`,`rf`] >> strip_tac >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sd`,`wenv ⊌ enva`,`emr`,`(sf,rf)`,`fv`,`w`]mp_tac Cevaluate_FUPDATE >>
    `fv ∉ free_vars FEMPTY emr` by (
      unabbrev_all_tac >>
      match_mp_tac fresh_var_not_in_any >>
      fsrw_tac[DNF_ss][SUBSET_DEF,Cpes_vars_thm,pes_to_Cpes_MAP,LET_THM,MEM_MAP,
                       UNCURRY,EXISTS_PROD,FORALL_PROD] >>
      fsrw_tac[DNF_ss][env_to_Cenv_MAP,MEM_MAP,EXISTS_PROD] >>
      PROVE_TAC[] ) >>
    `FDOM wenv = FDOM eenv` by fs[fmap_rel_def] >>
    fsrw_tac[DNF_ss][FORALL_PROD] >>
    map_every qx_gen_tac[`sg`,`rg`] >> strip_tac >>
    `(wenv ⊌ enva) |+ (fv,w) = wenv ⊌ enva |+ (fv,w)` by (
      `fv ∉ FDOM eenv` by (
        unabbrev_all_tac >>
        match_mp_tac fresh_var_not_in_any >>
        fs[fmap_rel_def] >>
        fsrw_tac[DNF_ss][Cpes_vars_thm] >>
        `set (MAP FST (env_to_Cenv m menv)) = Cpat_vars (SND (pat_to_Cpat m [] p))` by (
          fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair,FST_triple] >>
          METIS_TAC[Cpat_vars_pat_to_Cpat,pairTheory.SND,pairTheory.pair_CASES] ) >>
        fs[] >>
        fsrw_tac[DNF_ss][SUBSET_DEF,pes_to_Cpes_MAP,MEM_MAP,LET_THM] >>
        qpat_assum `MEM (p,x) pes` mp_tac >>
        rpt (pop_assum kall_tac) >>
        fsrw_tac[DNF_ss][pairTheory.EXISTS_PROD,pairTheory.UNCURRY] >>
        METIS_TAC[Cpat_vars_pat_to_Cpat,pairTheory.SND,pairTheory.pair_CASES] ) >>
      rw[FUNION_FUPDATE_2] ) >>
    disch_then(qspecl_then[`sg`,`rg`]mp_tac)>> fs[] >>
    qmatch_abbrev_tac`(P ⇒ Q) ⇒ R` >>
    `P` by (
      map_every qunabbrev_tac[`P`,`Q`,`R`] >>
      simp[FLOOKUP_UPDATE] >>
      conj_tac >- (
        spose_not_then strip_assume_tac >>
        unabbrev_all_tac >> rw[] >>
        qpat_assum`fresh_var X ∈ Y`mp_tac >>
        simp[] >>
        match_mp_tac fresh_var_not_in_any >>
        fsrw_tac[DNF_ss][SUBSET_DEF,Cpes_vars_thm,MEM_MAP,pes_to_Cpes_MAP,LET_THM,UNCURRY] >>
        PROVE_TAC[] ) >>
      conj_tac >- (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,pes_to_Cpes_MAP,env_to_Cenv_MAP,MEM_MAP,LET_THM,UNCURRY] >>
        PROVE_TAC[] ) >>
      match_mp_tac IN_FRANGE_DOMSUB_suff >>
      rw[] ) >>
    simp[] >>
    map_every qunabbrev_tac[`P`,`Q`,`R`] >>
    metis_tac[result_rel_syneq_trans,result_rel_syneq_sym,
              fmap_rel_syneq_sym,fmap_rel_syneq_trans]) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD]) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][bind_def,EXISTS_PROD] >>
    disj1_tac >>
    qspecl_then[`cenv`,`s`,`env`,`exp`,`(s',Rval v)`]mp_tac(CONJUNCT1 evaluate_closed) >>
    simp[] >> strip_tac >> fs[] >>
    rpt (first_x_assum (qspec_then `m` mp_tac)) >>
    rw[] >>
    qmatch_assum_rename_tac`syneq FEMPTY (v_to_Cv m v) w`[] >>
    pop_assum mp_tac >>
    Q.PAT_ABBREV_TAC`P = X ⊆ Y` >>
    `P` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      METIS_TAC[] ) >>
    simp[] >> qunabbrev_tac`P` >>
    qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva ea (sd,Rval w)` >>
    pop_assum kall_tac >>
    fsrw_tac[DNF_ss][] >>
    map_every qx_gen_tac[`se`,`re`] >>
    strip_tac >>
    qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sb envb eb (se,re)` >>
    CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
    map_every qexists_tac[`w`,`sd`] >>
    rw[] >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`envb`,`enva |+ (n,w)`,`eb`,`(se,re)`]mp_tac Cevaluate_any_syneq_any >>
    `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
     (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
      rw[] >> match_mp_tac(CONJUNCT1 v_to_Cv_closed) >> res_tac) >>
    `(free_vars FEMPTY ea ⊆ FDOM enva) ∧
     (free_vars FEMPTY eb ⊆ FDOM envb)` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,SUBSET_DEF,MEM_MAP,FORALL_PROD,EXISTS_PROD]) >>
    `(∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v) ∧
     (∀v. v ∈ FRANGE envb ⇒ Cclosed FEMPTY v)` by (
      unabbrev_all_tac >> conj_tac >>
      match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
      fsrw_tac[DNF_ss][MEM_MAP,env_to_Cenv_MAP,FORALL_PROD,EVERY_MEM] >>
      rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac >> fs[] ) >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`ea`,`(sd,Rval w)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
    simp[] >> strip_tac >>
    qmatch_abbrev_tac`(P ⇒ Q) ⇒ R` >>
    `P` by (
      unabbrev_all_tac >>
      conj_tac >- (
        rw[fmap_rel_def,env_to_Cenv_MAP,FAPPLY_FUPDATE_THM] >>
        rw[] ) >>
      fsrw_tac[DNF_ss][] >>
      match_mp_tac IN_FRANGE_DOMSUB_suff >>
      simp[] ) >>
    simp[] >>
    unabbrev_all_tac >>
    fsrw_tac[DNF_ss][FORALL_PROD] >>
    metis_tac[result_rel_syneq_trans,fmap_rel_syneq_trans] ) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD]) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM,FST_triple] >>
    fs[] >>
    rw[defs_to_Cdefs_MAP] >>
    rw[Once Cevaluate_cases,FOLDL_FUPDATE_LIST] >>
    `FV exp ⊆ set (MAP FST funs) ∪ set (MAP FST env)` by (
      fsrw_tac[DNF_ss][SUBSET_DEF,pairTheory.FORALL_PROD,MEM_MAP,pairTheory.EXISTS_PROD] >>
      METIS_TAC[] ) >>
    fs[] >>
    `EVERY closed (MAP (FST o SND) (build_rec_env tvs funs env))` by (
      match_mp_tac build_rec_env_closed >>
      fs[] >>
      fsrw_tac[DNF_ss][SUBSET_DEF,pairTheory.FORALL_PROD,MEM_MAP,pairTheory.EXISTS_PROD,MEM_EL,FST_5tup] >>
      METIS_TAC[] ) >>
    fs[] >>
    first_x_assum (qspec_then `m` mp_tac) >>
    fs[] >>
    simp_tac std_ss [build_rec_env_def,bind_def,FOLDR_CONS_5tup] >>
    fsrw_tac[DNF_ss][EXISTS_PROD,FORALL_PROD] >>
    simp_tac std_ss [FUNION_alist_to_fmap] >>
    Q.PAT_ABBREV_TAC`ee = alist_to_fmap (env_to_Cenv X Y)` >>
    simp_tac (srw_ss()) [env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
    simp_tac (srw_ss()) [v_to_Cv_def,LET_THM,pairTheory.UNCURRY,defs_to_Cdefs_MAP] >>
    Q.PAT_ABBREV_TAC`ls:(string#Cv) list = MAP f funs` >>
    `ALL_DISTINCT (MAP FST ls)` by (
      unabbrev_all_tac >>
      rw[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_triple] ) >>
    rw[FUPDATE_LIST_ALL_DISTINCT_REVERSE] >>
    rw[MEM_MAP,FORALL_PROD,EXISTS_PROD] >>
    fs[FST_5tup] >>
    qmatch_assum_rename_tac `Cevaluate FEMPTY FEMPTY X Y Z (p1,p2)`["X","Y","Z"] >>
    map_every qexists_tac[`p1`,`p2`] >>
    reverse conj_tac >- METIS_TAC[] >>
    reverse conj_tac >- METIS_TAC[] >>
    spose_not_then strip_assume_tac >>
    pop_assum mp_tac >> rw[EL_MAP,UNCURRY]) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    rw[Once Cevaluate_cases] ) >>
  strip_tac >- (
    rw[] >>
    rw[Once (CONJUNCT2 Cevaluate_cases)] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    qspecl_then[`cenv`,`s`,`env`,`exp`,`(s',Rval v)`]mp_tac(CONJUNCT1 evaluate_closed) >>
    simp[] >> strip_tac >> fs[] >>
    rpt (first_x_assum (qspec_then`m` mp_tac)) >>
    rw[] >>
    qmatch_assum_rename_tac`syneq FEMPTY (v_to_Cv m v) w`[] >>
    qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva ea (sd,Rval w)` >>
    pop_assum kall_tac >>
    CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`sd` >>
    CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`w` >> rw[] >>
    qmatch_assum_abbrev_tac`Cevaluate_list FEMPTY FEMPTY sb enva eb (se,Rval ws)` >>
    ntac 2 (pop_assum kall_tac) >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`enva`,`eb`,`(se,Rval ws)`]mp_tac Cevaluate_list_any_syneq_any >>
    `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >>
      match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
      fsrw_tac[DNF_ss][MEM_MAP,env_to_Cenv_MAP,EVERY_MEM,FORALL_PROD] >>
      rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
    `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
     (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
      rw[] >> match_mp_tac(CONJUNCT1 v_to_Cv_closed) >> res_tac) >>
    `(free_vars FEMPTY ea ⊆ FDOM enva) ∧
     (BIGUNION (IMAGE (free_vars FEMPTY) (set eb)) ⊆ FDOM enva)` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,SUBSET_DEF,MEM_MAP,FORALL_PROD,EXISTS_PROD]) >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`ea`,`(sd,Rval w)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
    simp[] >> strip_tac >>
    fsrw_tac[DNF_ss][FORALL_PROD] >>
    map_every qx_gen_tac[`sf`,`rf`] >>
    strip_tac >>
    map_every qexists_tac[`sf`,`rf`] >>
    simp[] >>
    conj_tac >- METIS_TAC[fmap_rel_syneq_trans] >>
    fsrw_tac[DNF_ss][EVERY2_EVERY,EVERY_MEM,FORALL_PROD,MEM_ZIP] >>
    `LENGTH vs = LENGTH ws` by rw[] >>
    qpat_assum `LENGTH ws = LENGTH rf` assume_tac >>
    fsrw_tac[DNF_ss][MEM_ZIP] >>
    rw[EL_MAP] >>
    rpt (first_x_assum (qspec_then`n`mp_tac)) >>
    rw[EL_MAP] >>
    METIS_TAC[syneq_trans] ) >>
  strip_tac >- (
    rw[] >>
    rw[Once (CONJUNCT2 Cevaluate_cases)] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] ) >>
  rw[] >>
  rw[Once (CONJUNCT2 Cevaluate_cases)] >>
  fsrw_tac[DNF_ss][EXISTS_PROD] >>
  disj2_tac >>
  qspecl_then[`cenv`,`s`,`env`,`exp`,`(s',Rval v)`]mp_tac(CONJUNCT1 evaluate_closed) >>
  simp[] >> strip_tac >> fs[] >>
  rpt (first_x_assum (qspec_then`m` mp_tac)) >>
  rw[] >>
  qmatch_assum_rename_tac`syneq FEMPTY (v_to_Cv m v) w`[] >>
  qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva ea (sd,Rval w)` >>
  pop_assum kall_tac >>
  CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`sd` >>
  CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`w` >> rw[] >>
  qmatch_assum_abbrev_tac`Cevaluate_list FEMPTY FEMPTY sb enva eb (se,Rerr err)` >>
  pop_assum kall_tac >>
  qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`enva`,`eb`,`(se,Rerr err)`]mp_tac Cevaluate_list_any_syneq_any >>
  `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
    unabbrev_all_tac >>
    match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
    fsrw_tac[DNF_ss][MEM_MAP,env_to_Cenv_MAP,EVERY_MEM,FORALL_PROD] >>
    rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
  `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
   (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
    unabbrev_all_tac >>
    fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
    rw[] >> match_mp_tac(CONJUNCT1 v_to_Cv_closed) >> res_tac) >>
  `(free_vars FEMPTY ea ⊆ FDOM enva) ∧
   (BIGUNION (IMAGE (free_vars FEMPTY) (set eb)) ⊆ FDOM enva)` by (
    unabbrev_all_tac >>
    fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,SUBSET_DEF,MEM_MAP,FORALL_PROD,EXISTS_PROD]) >>
  qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`ea`,`(sd,Rval w)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
  simp[] >> strip_tac >>
  fsrw_tac[DNF_ss][FORALL_PROD] >>
  METIS_TAC[fmap_rel_syneq_trans])

val exp_to_Cexp_thm1 = store_thm("exp_to_Cexp_thm1",
  ``(∀cenv s env exp res. evaluate cenv s env exp res ⇒
     (*
     (EVERY closed s) ∧
     (EVERY closed (MAP (FST o SND) env)) ∧
     *)
     (FV exp ⊆ set (MAP FST env)) ∧
     good_cenv cenv ∧ (SND res ≠ Rerr Rtype_error) ⇒
     ∀m. good_cmap cenv m.cnmap ⇒
       ∃Cres.
         Cevaluate FEMPTY
           (MAP (v_to_Cv m) s)
           (env_to_Cenv m env)
           (exp_to_Cexp m exp) Cres ∧
         EVERY2 (syneq FEMPTY FEMPTY) (MAP (v_to_Cv m) (FST res)) (FST Cres) ∧
         result_rel (syneq FEMPTY FEMPTY) (map_result (v_to_Cv m) (SND res)) (SND Cres)) ∧
    (∀cenv s env exps res. evaluate_list cenv s env exps res ⇒
     (*
     (EVERY closed s) ∧
     (EVERY closed (MAP (FST o SND) env)) ∧
     *)
     (BIGUNION (IMAGE FV (set exps)) ⊆ set (MAP FST env)) ∧
     good_cenv cenv ∧ (SND res ≠ Rerr Rtype_error) ⇒
     ∀m. good_cmap cenv m.cnmap ⇒
       ∃Cres.
         Cevaluate_list FEMPTY
           (MAP (v_to_Cv m) s)
           (env_to_Cenv m env)
           (MAP (exp_to_Cexp m) exps) Cres ∧
         EVERY2 (syneq FEMPTY FEMPTY) (MAP (v_to_Cv m) (FST res)) (FST Cres) ∧
         result_rel (EVERY2 (syneq FEMPTY FEMPTY)) (map_result (MAP (v_to_Cv m)) (SND res)) (SND Cres))``,
  ho_match_mp_tac evaluate_nicematch_strongind >>
  strip_tac >- rw[exp_to_Cexp_def,v_to_Cv_def] >>
  strip_tac >- rw[exp_to_Cexp_def] >>
  strip_tac >- (
    rw[exp_to_Cexp_def] >> fs[] >>
    first_x_assum(qspec_then`m`mp_tac) >> rw[] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][] >>
    disj1_tac >>
    Cases_on`Cres`>>fs[] >>
    metis_tac[] ) >>
  strip_tac >- (
    rw[exp_to_Cexp_def] >> fs[] >>
    first_x_assum(qspec_then`m`mp_tac) >> rw[] >>
    Cases_on`Cres` >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    disj2_tac >> disj1_tac >>
    qmatch_assum_rename_tac`Cevaluate FEMPTY FEMPTY X Y Z
      (s0,Rerr (Rraise (Int_error n)))`["X","Y","Z"] >>
    CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
    map_every qexists_tac[`n`,`s0`] >>
    simp[] >>
    qspecl_then[`cenv`,`s`,`env`,`exp`,`(s',Rerr(Rraise(Int_error n)))`]
      mp_tac(CONJUNCT1 evaluate_closed) >>
    simp[] >> strip_tac >> fs[] >>
    first_x_assum(qspec_then`m`mp_tac) >>
    simp[bind_def] >>
    qmatch_abbrev_tac`(P ⇒ Q) ⇒ R` >>
    `P` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      metis_tac[] ) >>
    simp[] >>
    map_every qunabbrev_tac[`P`,`Q`,`R`] >>
    rw[] >>
    qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY ss env0 exp0 res0` >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`ss`,`s0`,`env0`,`exp0`,`res0`]mp_tac
      Cevaluate_any_syneq_store >>
    simp[] >>
    `∀v. v ∈ FRANGE env0 ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >>
      match_mp_tac IN_FRANGE_alist_to_fmap_suff >> simp[] >>
      fs[EVERY_MEM,env_to_Cenv_MAP,MAP_MAP_o,v_to_Cv_def] >>
      fs[combinTheory.o_DEF,FORALL_PROD,MEM_MAP,EXISTS_PROD] >>
      rw[]>>rw[]>>
      match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
      metis_tac[] ) >>
    `free_vars FEMPTY exp0 ⊆ FDOM env0` by (
      unabbrev_all_tac >>
      fs[env_to_Cenv_MAP,MAP_MAP_o,v_to_Cv_def] >>
      fs[combinTheory.o_DEF,LAMBDA_PROD,FST_pair,FST_triple] ) >>
    simp[] >>
    `∀v. v ∈ FRANGE ss ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >>
      rw[FRANGE_store_to_Cstore,MEM_MAP] >>
      match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
      fs[EVERY_MEM] ) >>
    `∀v. v ∈ FRANGE (store_to_Cstore m s) ⇒ Cclosed FEMPTY v` by (
      rw[FRANGE_store_to_Cstore,MEM_MAP] >>
      match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
      fs[EVERY_MEM] ) >>
    qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY s1 env1 exp1 (s0,r1)` >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`s1`,`env1`,`exp1`,`(s0,r1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
    `free_vars FEMPTY exp1 ⊆ FDOM env1` by (
      unabbrev_all_tac >> simp[] >>
      simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,FST_pair,LAMBDA_PROD,FST_triple] ) >>
    `∀v. v ∈ FRANGE env1 ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >>
      match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
      simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,EXISTS_PROD,MEM_MAP] >>
      rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
      fs[MEM_MAP,EVERY_MEM,EXISTS_PROD] >>
      PROVE_TAC[] ) >>
    simp[Abbr`r1`] >> strip_tac >>
    simp[Abbr`res0`,EXISTS_PROD] >>
    strip_tac >>
    Q.PAT_ABBREV_TAC`env2 = env1 |+ X` >>
    `env0 = env2` by (
      unabbrev_all_tac >>
      rw[env_to_Cenv_MAP,alist_to_fmap_MAP_values,v_to_Cv_def] ) >>
    metis_tac[fmap_rel_syneq_trans, result_rel_syneq_trans] ) >>
  strip_tac >- (
    rpt gen_tac >>
    simp[AND_IMP_INTRO] >>
    Q.PAT_ABBREV_TAC`D = (X ∨ Y ∨ Z)` >>
    strip_tac >>
    rw[exp_to_Cexp_def] >>
    rfs[] >> fs[] >>
    first_x_assum (qspec_then`m`mp_tac) >>rw[]>>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][] >>
    disj2_tac >>
    qexists_tac`FST Cres` >>
    Cases_on`Cres`>>fs[] >>
    Cases_on`err`>>fs[]>>
    Cases_on`e`>>fs[markerTheory.Abbrev_def] ) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,v_to_Cv_def,
       exps_to_Cexps_MAP,vs_to_Cvs_MAP,
       Cevaluate_con] >>
    rw[syneq_cases] >>
    fsrw_tac[DNF_ss][EVERY2_EVERY,EVERY_MEM,pairTheory.FORALL_PROD] >>
    fsrw_tac[ETA_ss][] >>
    first_x_assum (qspec_then `m` mp_tac) >>
    rw[EXISTS_PROD]) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,v_to_Cv_def,
       exps_to_Cexps_MAP,Cevaluate_con] >>
    fsrw_tac[ETA_ss][] >>
    first_x_assum (qspec_then `m` mp_tac) >>
    rw[EXISTS_PROD]) >>
  strip_tac >- (
    fs[exp_to_Cexp_def,MEM_MAP,pairTheory.EXISTS_PROD,env_to_Cenv_MAP] >>
    rpt gen_tac >> rpt (disch_then strip_assume_tac) >> qx_gen_tac `m` >>
    rw[SIMP_RULE(srw_ss())[LAMBDA_PROD,UNCURRY](Q.SPEC`UNCURRY f`(INST_TYPE[alpha|->``:'a#'d``]alist_to_fmap_MAP_values))] >>
    `n ∈ FDOM (alist_to_fmap env)` by (
      rw[MEM_MAP,pairTheory.EXISTS_PROD] >> PROVE_TAC[] ) >>
    rw[o_f_FAPPLY,UNCURRY] >>
    PROVE_TAC[ALOOKUP_SOME_FAPPLY_alist_to_fmap,syneq_refl,FST] ) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,v_to_Cv_def,env_to_Cenv_MAP,LET_THM] >>
    srw_tac[DNF_ss][Once syneq_cases] >>
    rw[FINITE_has_fresh_string,fresh_var_not_in]) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >> fs[] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    first_x_assum(qspec_then`m`mp_tac)>>simp[]>>
    disch_then(Q.X_CHOOSE_THEN`s0`mp_tac)>>
    disch_then(Q.X_CHOOSE_THEN`v0`strip_assume_tac)>>
    CONV_TAC SWAP_EXISTS_CONV >>qexists_tac`s0`>>
    CONV_TAC SWAP_EXISTS_CONV >>qexists_tac`v0`>>
    simp[] >>
    fs[do_uapp_def,LET_THM,store_alloc_def] >>
    BasicProvers.EVERY_CASE_TAC >>
    fs[v_to_Cv_def,LET_THM] >- (
      BasicProvers.VAR_EQ_TAC >>
      BasicProvers.VAR_EQ_TAC >>
      fs[v_to_Cv_def] >>
      simp[Once syneq_cases] >>
      fs[fmap_rel_def] >>
      reverse conj_asm2_tac >- (
        numLib.LEAST_ELIM_TAC >>
        qabbrev_tac`n = LENGTH s2` >>
        conj_tac >- (
          qexists_tac`SUC n` >>
          srw_tac[ARITH_ss][] ) >>
        qx_gen_tac`a` >>
        srw_tac[ARITH_ss][] >>
        Cases_on`n < a` >- (res_tac >> fs[]) >>
        DECIDE_TAC ) >>
      fs[] >>
      conj_tac >- (
        srw_tac[ARITH_ss][EXTENSION] ) >>
      simp[FAPPLY_store_to_Cstore,FAPPLY_FUPDATE_THM] >>
      fs[FAPPLY_store_to_Cstore] >>
      qx_gen_tac`x` >>
      Cases_on`x < LENGTH s2` >- (
        srw_tac[ARITH_ss][] >>
        rw[rich_listTheory.EL_APPEND1] ) >>
      strip_tac >>
      `x = LENGTH s2` by DECIDE_TAC >>
      fs[] >>
      simp[rich_listTheory.EL_LENGTH_APPEND] ) >>
    fs[Q.SPECL[`FEMPTY`,`CLoc n`]syneq_cases] >>
    rpt BasicProvers.VAR_EQ_TAC >>
    fs[fmap_rel_def,store_lookup_def] >>
    simp[FLOOKUP_DEF] >>
    BasicProvers.VAR_EQ_TAC >>
    fs[FAPPLY_store_to_Cstore] ) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM,EXISTS_PROD] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][] ) >>
  strip_tac >- (
    ntac 2 gen_tac >>
    Cases >> fs[exp_to_Cexp_def] >>
    qx_gen_tac `e1` >>
    qx_gen_tac `e2` >>
    rw[LET_THM] >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][] >>
      disj1_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >> fsrw_tac[DNF_ss][] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >> fsrw_tac[DNF_ss][] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >> fsrw_tac[DNF_ss][] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >>
      rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[] >> strip_tac >> fs[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v2) w2`[] >>
      qmatch_assum_rename_tac`SND r1 = Rval w1`[] >>
      qmatch_assum_rename_tac`SND r2 = Rval w2`[] >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva e1a r1` >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sb enva e2a r2` >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`FST r1`,`enva`,`e2a`,`r2`]mp_tac Cevaluate_any_syneq_store >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,MEM_MAP,EXISTS_PROD] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM,FORALL_PROD,MEM_MAP,EXISTS_PROD] >>
        metis_tac[] ) >>
      `free_vars FEMPTY e2a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF] >>
        simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,FST_pair,LAMBDA_PROD,FST_triple]) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`enva`,`e2a`,`r2`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      `∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        fsrw_tac[DNF_ss][EVERY_MEM] >> rw[] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        rw[] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`r1`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF] >>
        simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,FST_pair,LAMBDA_PROD,FST_triple])>>
      `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        fsrw_tac[DNF_ss][EVERY_MEM] >> rw[] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        rw[] ) >>
      simp[] >> strip_tac >> strip_tac >>
      disch_then(Q.X_CHOOSE_THEN`r3`strip_assume_tac) >>
      qmatch_assum_rename_tac`syneq FEMPTY w2 w3`[] >>
      qmatch_assum_rename_tac `do_app s3 env (Opn opn) v1 v2 = SOME (s4,env',exp'')` [] >>
      qspecl_then[`cenv`,`s'`,`env`,`e2`,`(s3,Rval v2)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[] >> strip_tac >>
      Q.ISPECL_THEN[`s3`,`s4`,`env`,`Opn opn`,`v1`,`v2`,`env'`,`exp''`]mp_tac do_app_closed >>
      simp[] >> strip_tac >> fs[] >>
      fs[do_app_Opn_SOME] >>
      rpt BasicProvers.VAR_EQ_TAC >>
      qexists_tac`FST r3` >>
      qexists_tac `w1` >>
      qexists_tac `w3` >>
      qexists_tac`FST r1` >>
      PairCases_on`r1`>>PairCases_on`r3`>>
      fs[] >> rpt BasicProvers.VAR_EQ_TAC >> fs[] >>
      PairCases_on`res`>>fs[] >>
      PairCases_on`Cres`>>fs[] >>
      PairCases_on`r2`>>fs[] >>
      fs[v_to_Cv_def,Q.SPECL[`FEMPTY`,`CLitv (IntLit x)`]syneq_cases,i0_def] >>
      rpt BasicProvers.VAR_EQ_TAC >>
      fs[v_to_Cv_def,Q.SPECL[`FEMPTY`,`CLitv (IntLit x)`]syneq_cases,i0_def] >>
      rpt BasicProvers.VAR_EQ_TAC >>
      rpt(qpat_assum`T`kall_tac) >>
      `res0 = s3` by (
        qpat_assum`evaluate cenv s3 env X Y`mp_tac >>
        BasicProvers.CASE_TAC >>
        simp[Once evaluate_cases] ) >>
      BasicProvers.VAR_EQ_TAC >>
      qabbrev_tac`sc = store_to_Cstore m res0` >>
      `fmap_rel (syneq FEMPTY) sc r30` by
        metis_tac[fmap_rel_syneq_trans] >>
      Cases_on`opn`>>fs[]>>
      fs[v_to_Cv_def,opn_lookup_def,i0_def] >>
      Cases_on`n2=0`>>fs[v_to_Cv_def] )
    >- (
      qmatch_assum_rename_tac `do_app s3 env (Opb opb) v1 v2 = SOME (s4,env',exp'')` [] >>
      fs[] >>
      qmatch_assum_rename_tac`evaluate cenv s env e1 (s1,Rval v1)`[] >>
      qmatch_assum_rename_tac`evaluate cenv s1 env e2 (s2,Rval v2)`[] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s1,Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[] >> strip_tac >>
      qspecl_then[`cenv`,`s1`,`env`,`e2`,`(s2,Rval v2)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[] >> strip_tac >>
      fs[] >>
      Q.ISPECL_THEN[`s2`,`s4`,`env`,`Opb opb`,`v1`,`v2`,`env'`,`exp''`]mp_tac do_app_closed >>
      simp[] >> strip_tac >>
      fs[] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >> rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v2) w2`[] >>
      Cases_on`Cres`>> Cases_on`Cres'`>> Cases_on`Cres''`>>fs[]>>rw[]>>
      fs[do_app_Opb_SOME]>>rw[]>>fs[v_to_Cv_def]>>rw[]>>fs[]>>rw[]>>
      fs[v_to_Cv_def]>>fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases]>>rw[]>>
      fs[exp_to_Cexp_def]>>rw[]>>
      qabbrev_tac`sa = store_to_Cstore m s` >>
      qabbrev_tac`sb = store_to_Cstore m s1` >>
      qabbrev_tac`sc = store_to_Cstore m s2` >>
      fs[]>>rw[]>>
      qmatch_assum_rename_tac`fmap_rel (syneq FEMPTY) sb sd`[]>>
      qmatch_assum_rename_tac`fmap_rel (syneq FEMPTY) sc se`[]>>
      qabbrev_tac`enva = alist_to_fmap(env_to_Cenv m env)`>>
      qabbrev_tac`e1a = exp_to_Cexp m e1`>>
      qabbrev_tac`e2a = exp_to_Cexp m e2`>>
      qabbrev_tac`w1 = CLitv (IntLit n1)`>>
      qabbrev_tac`w2 = CLitv (IntLit n2)`>>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,MEM_MAP,EXISTS_PROD] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM,EXISTS_PROD,MEM_MAP] >>
        metis_tac[] ) >>
      `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      `∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      `∀v. v ∈ FRANGE sc ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `free_vars FEMPTY e2a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`enva`,`e2a`,`(se,Rval w2)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >>
      Cases_on `opb` >> fsrw_tac[DNF_ss][EXISTS_PROD,opb_lookup_def]
      >- (
        rw[Once Cevaluate_cases] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        srw_tac[DNF_ss][] >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(se,Rval w2)`]mp_tac(Cevaluate_any_syneq_store) >>
        fsrw_tac[DNF_ss][EXISTS_PROD] >>
        qx_gen_tac`sf` >>
        qx_gen_tac`w3` >>
        strip_tac >>
        qexists_tac`sf`>>
        qexists_tac `w1` >>
        qexists_tac `w3` >>
        qexists_tac`sd`>>
        simp[] >>
        reverse conj_tac >- metis_tac[fmap_rel_syneq_trans] >>
        map_every qunabbrev_tac[`w1`,`w2`] >>
        fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] )
      >- (
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
        map_every qexists_tac [`w1`,`sd`] >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(se,Rval w2)`]mp_tac Cevaluate_any_syneq_store >>
        fsrw_tac[DNF_ss][EXISTS_PROD] >>
        qx_gen_tac`sf` >> qx_gen_tac`w3` >>
        strip_tac >>
        Q.PAT_ABBREV_TAC`fv = fresh_var X` >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sd`,`enva`,`e2a`,`(sf,Rval w3)`,`fv`,`w1`]mp_tac Cevaluate_FUPDATE >>
        `fv ∉ free_vars FEMPTY e2a` by (
          unabbrev_all_tac >>
          match_mp_tac fresh_var_not_in_any >>
          rw[] ) >>
        fsrw_tac[DNF_ss][EXISTS_PROD] >>
        qx_gen_tac`sg`>>qx_gen_tac`w4`>>
        strip_tac >>
        CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
        map_every qexists_tac [`w4`,`sg`] >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[FAPPLY_FUPDATE_THM,NOT_fresh_var] >>
        map_every qunabbrev_tac[`w1`,`w2`] >> rw[] >>
        fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >> rw[] >>
        fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >> rw[] >>
        rw[integerTheory.int_gt] >>
        metis_tac[fmap_rel_syneq_trans])
      >- (
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        srw_tac[DNF_ss][] >>
        CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
        qexists_tac`sd`>>
        qexists_tac`w2`>>
        qexists_tac`w1`>>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(se,Rval w2)`]mp_tac(Cevaluate_any_syneq_store) >>
        fsrw_tac[DNF_ss][EXISTS_PROD,Abbr`w2`,Abbr`w1`] >>
        qx_gen_tac`sf` >>
        qx_gen_tac`w3` >>
        strip_tac >>
        fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >>
        `fmap_rel (syneq FEMPTY) sc sf` by PROVE_TAC[fmap_rel_syneq_trans] >>
        qexists_tac`sf`>>
        rw[CompileTheory.i1_def] >>
        ARITH_TAC )
      >- (
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
        map_every qexists_tac [`w1`,`sd`] >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(se,Rval w2)`]mp_tac Cevaluate_any_syneq_store >>
        fsrw_tac[DNF_ss][EXISTS_PROD] >>
        qx_gen_tac`sf` >> qx_gen_tac`w3` >>
        strip_tac >>
        Q.PAT_ABBREV_TAC`fv = fresh_var X` >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sd`,`enva`,`e2a`,`(sf,Rval w3)`,`fv`,`w1`]mp_tac Cevaluate_FUPDATE >>
        `fv ∉ free_vars FEMPTY e2a` by (
          unabbrev_all_tac >>
          match_mp_tac fresh_var_not_in_any >>
          rw[] ) >>
        fsrw_tac[DNF_ss][EXISTS_PROD] >>
        qx_gen_tac`sg`>>qx_gen_tac`w4`>>
        strip_tac >>
        CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
        map_every qexists_tac [`w4`,`sg`] >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[FAPPLY_FUPDATE_THM,NOT_fresh_var] >>
        rw[Once Cevaluate_cases] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        rw[Once (CONJUNCT2 Cevaluate_cases)] >>
        srw_tac[DNF_ss][] >>
        rw[FAPPLY_FUPDATE_THM,NOT_fresh_var] >>
        map_every qunabbrev_tac[`w1`,`w2`] >> rw[] >>
        fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >> rw[] >>
        `fmap_rel (syneq FEMPTY) sc sg` by PROVE_TAC[fmap_rel_syneq_trans] >>
        fs[Q.SPECL[`FEMPTY`,`CLitv l`]syneq_cases] >> rw[] >>
        rw[CompileTheory.i1_def] >>
        ARITH_TAC) )
    >- (
      rw[Once Cevaluate_cases] >>
      srw_tac[DNF_ss][] >>
      disj1_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      srw_tac[DNF_ss][] >>
      fs[] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac >>
      qspecl_then[`cenv`,`s'`,`env`,`e2`,`(s3,Rval v2)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac >>
      Q.ISPECL_THEN[`s3`,`s''`,`env`,`Equality`,`v1`,`v2`,`env'`,`exp''`]mp_tac do_app_closed >>
      simp[]>>strip_tac>>
      fs[] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >>
      rw[EXISTS_PROD] >>
      qmatch_assum_rename_tac `syneq FEMPTY(v_to_Cv m v1) w1`[] >>
      qmatch_assum_rename_tac `syneq FEMPTY(v_to_Cv m v2) w2`[] >>
      qabbrev_tac`sa = store_to_Cstore m s` >>
      qabbrev_tac`sb = store_to_Cstore m s'` >>
      qabbrev_tac`sc = store_to_Cstore m s3` >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva e1a X` >>
      qmatch_assum_rename_tac`Abbrev(X=(sd,Rval w1))`[]>>
      qunabbrev_tac`X` >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sb enva e2a X` >>
      qmatch_assum_rename_tac`Abbrev(X=(se,Rval w2))`[]>>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`X`]mp_tac Cevaluate_any_syneq_store >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,MEM_MAP,EXISTS_PROD] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM,EXISTS_PROD,MEM_MAP] >>
        metis_tac[] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `free_vars FEMPTY e2a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      `∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`enva`,`e2a`,`X`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[Abbr`X`] >> strip_tac >>
      fsrw_tac[DNF_ss][EXISTS_PROD,FORALL_PROD] >>
      map_every qx_gen_tac[`sf`,`w3`] >>
      strip_tac >>
      map_every qexists_tac[`sf`,`w1`,`w3`,`sd`] >>
      simp[] >>
      fs[do_app_def] >>
      rpt BasicProvers.VAR_EQ_TAC >>
      fs[] >>
      rpt BasicProvers.VAR_EQ_TAC >>
      fs[v_to_Cv_def,Q.SPECL[`c`,`CLitv l`]syneq_cases] >>
      fs[exp_to_Cexp_def] >>
      `fmap_rel (syneq FEMPTY) sc sf` by PROVE_TAC[fmap_rel_syneq_trans] >>
      cheat )
    >- (
      rw[Once Cevaluate_cases] >>
      srw_tac[DNF_ss][] >>
      disj1_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)]>>
      rw[Once(CONJUNCT2 Cevaluate_cases)]>>
      fsrw_tac[DNF_ss][] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[] >> strip_tac >>
      qspecl_then[`cenv`,`s'`,`env`,`e2`,`(s3,Rval v2)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[] >> strip_tac >>
      Q.ISPECL_THEN[`s3`,`s''`,`env`,`Opapp`,`v1`,`v2`,`env'`,`exp''`]mp_tac do_app_closed >>
      simp[] >> strip_tac >>
      fs[] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >>
      srw_tac[DNF_ss][EXISTS_PROD] >>
      qmatch_assum_rename_tac `syneq FEMPTY(v_to_Cv m v1) w1`[] >>
      qmatch_assum_rename_tac `syneq FEMPTY(v_to_Cv m v2) w2`[] >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w1)`>>
      pop_assum kall_tac >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sb enva e2a (se,Rval w2)`>>
      pop_assum kall_tac >>
      qmatch_assum_abbrev_tac`fmap_rel (syneq FEMPTY) sc se` >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(se,Rval w2)`]mp_tac Cevaluate_any_syneq_store >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,MEM_MAP,EXISTS_PROD] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM,EXISTS_PROD,MEM_MAP] >>
        metis_tac[] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `free_vars FEMPTY e2a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      `∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >>
      fsrw_tac[DNF_ss][EXISTS_PROD,FORALL_PROD] >>
      map_every qx_gen_tac[`sf`,`w3`] >>
      strip_tac >>
      CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
      qexists_tac`w3` >>
      qexists_tac`sf` >>
      `∃env1 ns' defs n. w1 = CRecClos env1 ns' defs n` by (
        imp_res_tac do_Opapp_SOME_CRecClos >> rw[] ) >>
      CONV_TAC (RESORT_EXISTS_CONV (fn ls => List.drop(ls,4)@List.take(ls,4))) >>
      map_every qexists_tac[`n`,`defs`,`ns'`,`env1`,`sd`] >>
      rw[] >>
      fs[Q.SPECL[`FEMPTY`,`CRecClos env1 ns' defs n`]Cclosed_cases] >>
      fs[MEM_EL] >> rw[] >>
      fs[do_app_Opapp_SOME] >- (
        rw[] >> fs[v_to_Cv_def,LET_THM] >>
        fs[Q.SPECL[`c`,`CRecClos env1 ns' defs zz`]syneq_cases] >>
        rw[] >> fs[] >>
        Q.PAT_ABBREV_TAC`env2 = X:string|->Cv` >>
        qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sc env3 e3a (sg,r)` >>
        ntac 2 (pop_assum kall_tac) >>
        `fmap_rel (syneq FEMPTY) sc sf` by PROVE_TAC[fmap_rel_syneq_trans] >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sc`,`sf`,`env3`,`e3a`,`(sg,r)`]mp_tac Cevaluate_any_syneq_store >>
        `free_vars FEMPTY e3a ⊆ FDOM env3` by(
          unabbrev_all_tac >> fs[] >>
          rw[env_to_Cenv_MAP,MAP_MAP_o] >>
          rw[combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair,FST_triple] ) >>
        `∀v. v ∈ FRANGE env3 ⇒ Cclosed FEMPTY v` by(
          unabbrev_all_tac >>
          fs[env_to_Cenv_MAP] >>
          match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
          fs[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
          rw[bind_def,MEM_MAP,pairTheory.EXISTS_PROD] >>
          match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
          fs[EVERY_MEM,bind_def,MEM_MAP,pairTheory.EXISTS_PROD] >>
          PROVE_TAC[]) >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sd`,`enva`,`e2a`,`(sf,Rval w3)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
        `∀v. v ∈ FRANGE sc ⇒ Cclosed FEMPTY v` by (
          unabbrev_all_tac >>
          simp[FRANGE_store_to_Cstore,MEM_MAP] >>
          fsrw_tac[DNF_ss][EVERY_MEM] >>
          PROVE_TAC[v_to_Cv_closed] ) >>
        simp[] >> strip_tac >>
        fsrw_tac[DNF_ss][EXISTS_PROD,FORALL_PROD] >>
        map_every qx_gen_tac[`sh`,`w4`]>>strip_tac>>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sf`,`env3`,`e3a`,`(sh,w4)`]mp_tac Cevaluate_free_vars_env >>
        fsrw_tac[DNF_ss][FORALL_PROD] >>
        map_every qx_gen_tac[`si`,`w5`]>>strip_tac>>
        `free_vars FEMPTY e3a ⊆ FDOM env2` by (
          unabbrev_all_tac >> fs[] ) >>
        `fmap_rel (syneq FEMPTY)
           (DRESTRICT env3 (free_vars FEMPTY e3a))
           (DRESTRICT env2 (free_vars FEMPTY e3a))` by(
          rw[fmap_rel_def,FDOM_DRESTRICT] >-
            fs[SUBSET_INTER_ABSORPTION,INTER_COMM] >>
          `x ∈ FDOM env2` by fs[SUBSET_DEF] >>
          rw[DRESTRICT_DEF] >>
          qunabbrev_tac `env3` >>
          qmatch_abbrev_tac `syneq FEMPTY (alist_to_fmap al ' x) (env2 ' x)` >>
          `∃v. ALOOKUP al x = SOME v` by (
            Cases_on `ALOOKUP al x` >> fs[] >>
            imp_res_tac ALOOKUP_FAILS >>
            unabbrev_all_tac >>
            fs[MEM_MAP,pairTheory.EXISTS_PROD] ) >>
          imp_res_tac ALOOKUP_SOME_FAPPLY_alist_to_fmap >>
          pop_assum(SUBST1_TAC) >>
          fs[Abbr`al`,env_to_Cenv_MAP,ALOOKUP_MAP] >>
          fs[bind_def] >- (
            rw[Abbr`env2`] >>
            rw[extend_rec_env_def] >>
            PROVE_TAC[syneq_trans]) >>
          rw[Abbr`env2`,extend_rec_env_def] >>
          simp[FAPPLY_FUPDATE_THM] >>
          Cases_on`n'=x` >- (
            rw[] >> PROVE_TAC[syneq_trans] ) >>
          simp[] >>
          rw[] >- (
            fs[Abbr`e3a`,NOT_fresh_var] >>
            fs[FLOOKUP_DEF,optionTheory.OPTREL_def] >>
            fsrw_tac[DNF_ss][] >>
            metis_tac[NOT_fresh_var,FINITE_FV,optionTheory.SOME_11]) >>
          fs[Abbr`e3a`] >>
          fs[FLOOKUP_DEF,optionTheory.OPTREL_def] >>
          fsrw_tac[DNF_ss][] >>
          metis_tac[NOT_fresh_var,FINITE_FV,optionTheory.SOME_11]) >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sf`,
          `DRESTRICT env3 (free_vars FEMPTY e3a)`,
          `DRESTRICT env2 (free_vars FEMPTY e3a)`,
          `e3a`,`(si,w5)`]mp_tac Cevaluate_any_syneq_env >>
        simp[FDOM_DRESTRICT] >>
        `∀v. v ∈ FRANGE env2 ⇒ Cclosed FEMPTY v` by (
          unabbrev_all_tac >>
          simp[extend_rec_env_def] >>
          fsrw_tac[DNF_ss][] >>
          match_mp_tac IN_FRANGE_DOMSUB_suff >> simp[] >>
          match_mp_tac IN_FRANGE_FUPDATE_suff >> simp[] >>
          rw[Once Cclosed_cases] ) >>
        qmatch_abbrev_tac`(P ⇒ Q) ⇒ R` >>
        `P` by (
          map_every qunabbrev_tac[`P`,`Q`,`R`] >>
          conj_tac >> match_mp_tac IN_FRANGE_DRESTRICT_suff >>
          simp[] ) >>
        simp[] >>
        map_every qunabbrev_tac[`P`,`Q`,`R`] >>
        pop_assum kall_tac >>
        fsrw_tac[DNF_ss][FORALL_PROD] >>
        map_every qx_gen_tac [`sj`,`w6`] >>
        strip_tac >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sf`,`env2`,`e3a`,`(sj,w6)`]mp_tac Cevaluate_any_super_env >>
        fsrw_tac[DNF_ss][EXISTS_PROD] >>
        map_every qx_gen_tac [`sk`,`w7`] >>
        strip_tac >>
        map_every qexists_tac[`w7`,`sk`] >>
        simp[] >>
        PROVE_TAC[fmap_rel_syneq_trans,result_rel_syneq_trans] ) >>
      rw[] >>
      fs[v_to_Cv_def,LET_THM,defs_to_Cdefs_MAP] >>
      fs[Q.SPECL[`c`,`CRecClos env1 ns' defs X`]syneq_cases] >>
      rw[] >> fs[] >> rw[] >> rfs[] >> rw[] >>
      PairCases_on`z`>>fs[]>>rw[]>>
      qpat_assum `X < LENGTH Y` assume_tac >>
      fs[EL_MAP] >>
      qmatch_assum_rename_tac `ALL_DISTINCT (MAP FST ns)`[] >>
      qabbrev_tac`q = EL n' ns` >>
      PairCases_on `q` >>
      pop_assum (mp_tac o SYM o SIMP_RULE std_ss [markerTheory.Abbrev_def]) >> rw[] >>
      fs[] >> rw[] >>
      `ALOOKUP ns q0 = SOME (q1,q2,q3,q4)` by (
        match_mp_tac ALOOKUP_ALL_DISTINCT_MEM >>
        rw[MEM_EL] >> PROVE_TAC[] ) >>
      fs[] >> rw[] >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sc env3 ee r` >>
      qmatch_assum_rename_tac`Abbrev(r=(sg,w4))`[]>>
      qmatch_assum_rename_tac`EL n' ns = (q0,q1,q2,q3,q4)`[]>>
      Q.PAT_ABBREV_TAC`env2 = X:string|->Cv` >>
      qmatch_assum_abbrev_tac `result_rel (syneq FEMPTY) rr w4` >>
      fs[Q.SPEC`Recclosure l ns q0`closed_cases] >>
      `free_vars FEMPTY ee ⊆ FDOM env2` by (
        first_x_assum (qspecl_then [`n'`,`[q2]`,`INL ee`] mp_tac) >>
        unabbrev_all_tac >> fs[] >>
        rw[EL_MAP] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sd`,`enva`,`e2a`,`(sf,Rval w3)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >>
      `∀v. v ∈ FRANGE env2 ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >> fs[] >>
        fs[extend_rec_env_def] >>
        qx_gen_tac `v` >>
        Cases_on `v=w3` >> fs[] >>
        match_mp_tac IN_FRANGE_DOMSUB_suff >>
        fs[FOLDL_FUPDATE_LIST] >>
        match_mp_tac IN_FRANGE_FUPDATE_LIST_suff >> fs[] >>
        fs[MAP_MAP_o,MEM_MAP,pairTheory.EXISTS_PROD] >>
        fsrw_tac[DNF_ss][] >>
        rw[Once Cclosed_cases,MEM_MAP,pairTheory.EXISTS_PROD]
          >- PROVE_TAC[]
          >- ( first_x_assum match_mp_tac >>
               PROVE_TAC[] ) >>
        Cases_on `cb` >> fs[] >>
        pop_assum mp_tac >>
        fs[EL_MAP,pairTheory.UNCURRY]) >>
      `fmap_rel (syneq FEMPTY) sc sf` by metis_tac[fmap_rel_syneq_trans] >>
      `∀v. v ∈ FRANGE env3 ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        simp[env_to_Cenv_MAP,build_rec_env_MAP,MAP_MAP_o,bind_def,MEM_MAP,EXISTS_PROD] >>
        fsrw_tac[DNF_ss][] >>
        conj_tac >- (
          match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> rw[] ) >>
        conj_tac >- (
          rpt gen_tac >> strip_tac >>
          match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
          rw[Once closed_cases,MEM_MAP,EXISTS_PROD] >>
          metis_tac[] ) >>
        rpt gen_tac >> strip_tac >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM,build_rec_env_MAP,MEM_MAP,EXISTS_PROD,bind_def] >>
        metis_tac[] ) >>
      `free_vars FEMPTY ee ⊆ FDOM env3` by (
        unabbrev_all_tac >> fs[] >>
        rw[env_to_Cenv_MAP,MAP_MAP_o] >>
        rw[combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair,FST_triple] ) >>
      `∀v. v ∈ FRANGE sc ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        fsrw_tac[DNF_ss][FORALL_PROD] >> rw[] >>
        fs[EVERY_MEM] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        PROVE_TAC[] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sc`,`sf`,`env3`,`ee`,`r`]mp_tac Cevaluate_any_syneq_store >>
      fsrw_tac[DNF_ss][FORALL_PROD,Abbr`r`] >>
      `fmap_rel (syneq FEMPTY)
         (DRESTRICT env3 (free_vars FEMPTY ee))
         (DRESTRICT env2 (free_vars FEMPTY ee))` by (
        rw[fmap_rel_def,FDOM_DRESTRICT] >-
          fs[SUBSET_INTER_ABSORPTION,INTER_COMM] >>
        `x ∈ FDOM env2` by fs[SUBSET_DEF] >>
        rw[DRESTRICT_DEF] >>
        qunabbrev_tac `env3` >>
        qmatch_abbrev_tac `syneq FEMPTY (alist_to_fmap al ' x) (env2 ' x)` >>
        `∃v. ALOOKUP al x = SOME v` by (
          Cases_on `ALOOKUP al x` >> fs[] >>
          imp_res_tac ALOOKUP_FAILS >>
          unabbrev_all_tac >>
          fs[MEM_MAP,pairTheory.EXISTS_PROD] ) >>
        imp_res_tac ALOOKUP_SOME_FAPPLY_alist_to_fmap >>
        qpat_assum `alist_to_fmap al ' x = X`(SUBST1_TAC) >>
        fs[Abbr`al`,env_to_Cenv_MAP,ALOOKUP_MAP] >> rw[] >>
        fs[bind_def] >- (
          rw[Abbr`env2`] >>
          rw[extend_rec_env_def] >>
          PROVE_TAC[syneq_trans]) >>
        Cases_on `q2=x`>>fs[] >- (
          rw[] >>
          rw[Abbr`env2`,extend_rec_env_def] >>
          PROVE_TAC[syneq_trans]) >>
        qpat_assum `ALOOKUP X Y = SOME Z` mp_tac >>
        asm_simp_tac(srw_ss())[build_rec_env_def,bind_def,FOLDR_CONS_5tup] >>
        rw[ALOOKUP_APPEND] >>
        Cases_on `MEM x (MAP FST ns)` >>
        fs[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair,FST_triple] >- (
          qpat_assum `X = SOME v'` mp_tac >>
          qho_match_abbrev_tac `((case ALOOKUP (MAP ff ns) x of
            NONE => ALOOKUP (MAP fg env'') x | SOME v => SOME v) = SOME v') ⇒ P` >>
          `MAP FST (MAP ff ns) = MAP FST ns` by (
            asm_simp_tac(srw_ss())[LIST_EQ_REWRITE,Abbr`ff`] >>
            qx_gen_tac `y` >> strip_tac >>
            fs[MAP_MAP_o,combinTheory.o_DEF,EL_MAP] >>
            qabbrev_tac `yy = EL y ns` >>
            PairCases_on `yy` >> fs[] ) >>
          `ALL_DISTINCT (MAP FST (MAP ff ns))` by PROVE_TAC[] >>
          `MEM (x,v_to_Cv m (Recclosure env'' ns x)) (MAP ff ns)` by (
            rw[Abbr`ff`,MEM_MAP,pairTheory.EXISTS_PROD] >>
            fs[MEM_MAP,pairTheory.EXISTS_PROD,MAP_MAP_o,combinTheory.o_DEF,UNCURRY] >>
            PROVE_TAC[] ) >>
          imp_res_tac ALOOKUP_ALL_DISTINCT_MEM >>
          fs[] >> rw[Abbr`P`] >>
          rw[v_to_Cv_def] >>
          rw[Abbr`env2`,extend_rec_env_def,FOLDL_FUPDATE_LIST] >>
          rw[FAPPLY_FUPDATE_THM] >>
          ho_match_mp_tac FUPDATE_LIST_ALL_DISTINCT_APPLY_MEM >>
          fs[MAP_MAP_o,combinTheory.o_DEF] >>
          fsrw_tac[ETA_ss][] >>
          fs[pairTheory.LAMBDA_PROD] >>
          fsrw_tac[DNF_ss][MEM_MAP,pairTheory.EXISTS_PROD] >>
          rw[Once syneq_cases] >>
          fs[defs_to_Cdefs_MAP] >>
          qmatch_assum_rename_tac `MEM (x,z0,z1,z2,z3) ns`[] >>
          map_every qexists_tac [`z0`,`z1`,`z2`,`z3`] >> fs[] >>
          rw[] >>
          fs[EVERY_MEM,pairTheory.FORALL_PROD] >>
          fs[MEM_MAP,pairTheory.EXISTS_PROD] >>
          fsrw_tac[DNF_ss][] >>
          fs[env_to_Cenv_MAP,ALOOKUP_MAP] >>
          fsrw_tac[ETA_ss][] >>
          fs[Abbr`Cenv`] >>
          fs[ALOOKUP_MAP] >>
          fsrw_tac[ETA_ss][] >>
          metis_tac[]) >>
        qpat_assum `X = SOME v'` mp_tac >>
        qho_match_abbrev_tac `((case ALOOKUP (MAP ff ns) x of
          NONE => ALOOKUP (MAP fg env'') x | SOME v => SOME v) = SOME v') ⇒ P` >>
        `MAP FST (MAP ff ns) = MAP FST ns` by (
          asm_simp_tac(srw_ss())[LIST_EQ_REWRITE,Abbr`ff`] >>
          qx_gen_tac `y` >> strip_tac >>
          fs[MAP_MAP_o,combinTheory.o_DEF,EL_MAP] >>
          qabbrev_tac `yy = EL y ns` >>
          PairCases_on `yy` >> fs[] ) >>
        `ALOOKUP (MAP ff ns) x= NONE` by (
          rw[ALOOKUP_NONE]) >>
        rw[Abbr`P`] >>
        rw[Abbr`env2`] >>
        rw[extend_rec_env_def,FOLDL_FUPDATE_LIST] >>
        rw[FAPPLY_FUPDATE_THM] >>
        ho_match_mp_tac FUPDATE_LIST_APPLY_HO_THM >>
        disj2_tac >>
        fs[MAP_MAP_o,combinTheory.o_DEF] >>
        fsrw_tac[ETA_ss][] >>
        fsrw_tac[DNF_ss][EVERY_MEM,pairTheory.FORALL_PROD] >>
        fsrw_tac[DNF_ss][optionTheory.OPTREL_def,FLOOKUP_DEF] >>
        fsrw_tac[DNF_ss][MEM_MAP,pairTheory.EXISTS_PROD] >>
        fs[Abbr`ee`] >>
        imp_res_tac ALOOKUP_MEM >>
        metis_tac[NOT_fresh_var,FINITE_FV,optionTheory.SOME_11] ) >>
      map_every qx_gen_tac[`sh`,`w5`] >> strip_tac >>
      qspecl_then [`FEMPTY`,`FEMPTY`,`sf`,`env3`,`ee`,`(sh,w5)`] mp_tac Cevaluate_free_vars_env >>
      simp[] >>
      fsrw_tac[DNF_ss][FORALL_PROD] >>
      map_every qx_gen_tac[`si`,`w6`] >> strip_tac >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sf`,
        `DRESTRICT env3 (free_vars FEMPTY ee)`,
        `DRESTRICT env2 (free_vars FEMPTY ee)`,
        `ee`,`(si,w6)`]mp_tac Cevaluate_any_syneq_env >>
      simp[FDOM_DRESTRICT] >>
      qmatch_abbrev_tac`(P ⇒ Q) ⇒ R` >>
      `P` by (
        map_every qunabbrev_tac[`P`,`Q`,`R`] >>
        conj_tac >> match_mp_tac IN_FRANGE_DRESTRICT_suff >>
        simp[] ) >>
      simp[] >>
      map_every qunabbrev_tac[`P`,`Q`,`R`] >>
      pop_assum kall_tac >>
      fsrw_tac[DNF_ss][FORALL_PROD] >>
      map_every qx_gen_tac [`sj`,`w7`] >>
      strip_tac >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sf`,`env2`,`ee`,`(sj,w7)`]mp_tac Cevaluate_any_super_env >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      map_every qx_gen_tac [`sk`,`w8`] >>
      strip_tac >>
      map_every qexists_tac[`w8`,`sk`] >>
      simp[] >>
      PROVE_TAC[fmap_rel_syneq_trans,result_rel_syneq_trans] )
    >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][] >>
      disj1_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      fsrw_tac[DNF_ss][] >>
      fs[do_app_def] >>
      Cases_on`v1`>>fs[] >>
      Cases_on`store_assign n v2 s3`>>fs[] >>
      rw[] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval (Loc n))`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac >> fs[] >>
      fs[store_assign_def] >> rw[] >> fs[] >> rw[] >>
      qspecl_then[`cenv`,`s'`,`env`,`e2`,`(s3,Rval v2)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac >>
      `EVERY closed (LUPDATE v2 n s3)` by (
        fs[EVERY_MEM] >>
        metis_tac[MEM_LUPDATE] ) >>
      fs[] >>
      rpt (first_x_assum (qspec_then`m`mp_tac)) >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >> rw[] >>
      fs[v_to_Cv_def,exp_to_Cexp_def] >>
      rw[] >> fs[] >> rw[] >>
      fs[Q.SPECL[`FEMPTY`,`CLoc n`]syneq_cases] >> rw[] >>
      CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`CLoc n` >> rw[] >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval (CLoc n))` >>
      pop_assum kall_tac >>
      qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sb enva e2a (se,w1)` >>
      qpat_assum`Abbrev (se  = X)`kall_tac >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(se,w1)`]mp_tac Cevaluate_any_syneq_store >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        simp[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,MEM_MAP,EXISTS_PROD] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM,EXISTS_PROD,MEM_MAP] >>
        metis_tac[] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `free_vars FEMPTY e2a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      `∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        simp[FRANGE_store_to_Cstore,MEM_MAP] >>
        srw_tac[DNF_ss][] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        fs[EVERY_MEM] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval (CLoc n))`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >>
      fsrw_tac[DNF_ss][FORALL_PROD] >>
      map_every qx_gen_tac[`sf`,`w2`] >>
      strip_tac >>
      fs[Abbr`w1`] >> rw[] >>
      qmatch_assum_rename_tac`syneq FEMPTY w1 w2`[] >>
      map_every qexists_tac[`sf`,`w2`,`sd`] >>
      simp[] >>
      fs[fmap_rel_def] >>
      conj_tac >- (rw[EXTENSION] >> PROVE_TAC[]) >>
      rw[FAPPLY_FUPDATE_THM,FAPPLY_store_to_Cstore,EL_LUPDATE] >-
        PROVE_TAC[syneq_trans] >>
      fs[FAPPLY_store_to_Cstore,EXTENSION] >>
      PROVE_TAC[syneq_trans])) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    ntac 2 gen_tac >>
    Cases >> fs[exp_to_Cexp_def] >>
    qx_gen_tac `e1` >>
    qx_gen_tac `e2` >>
    rw[LET_THM] >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      disj2_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      fsrw_tac[DNF_ss][] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[] >> strip_tac >> fs[] >>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >>
      rw[] >>
      disj2_tac >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sb enva e2a (sc,Rerr err)`>>
      pop_assum kall_tac >>
      qmatch_assum_rename_tac `fmap_rel (syneq FEMPTY) sb sd`[] >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(sc,Rerr err)`]mp_tac Cevaluate_any_syneq_store >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w1)`>>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EVERY_MEM,EXISTS_PROD,FORALL_PROD] >>
        rw[] >>
        match_mp_tac (CONJUNCT1 v_to_Cv_closed) >>
        PROVE_TAC[]) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `free_vars FEMPTY e2a ⊆ FDOM enva` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,env_to_Cenv_MAP,MEM_MAP,
                         EXISTS_PROD,FORALL_PROD] ) >>
      `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
        rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> PROVE_TAC[] ) >>
      `∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v` by (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
        rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> PROVE_TAC[] ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >>
      fsrw_tac[DNF_ss][FORALL_PROD] >>
      qx_gen_tac`se` >> strip_tac >>
      map_every qexists_tac [`se`,`sd`,`w1`] >> fs[] >>
      PROVE_TAC[fmap_rel_syneq_trans])
    >- (
      fs[] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac>>fs[]>>
      fsrw_tac[DNF_ss][EXISTS_PROD]>>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >>
      rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w1)` >>
      pop_assum kall_tac >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sb enva e2a (sc,Rerr err)` >>
      pop_assum kall_tac >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        imp_res_tac v_to_Cv_closed >>
        fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva ∧
       free_vars FEMPTY e2a ⊆ FDOM enva` by (
        fs[Abbr`e1a`,Abbr`e2a`,Abbr`enva`,env_to_Cenv_MAP,MAP_MAP_o,
           pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair,FST_triple] ) >>
      `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
       (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
         unabbrev_all_tac >>
         fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
         rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >> fs[] >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(sc,Rerr err)`]mp_tac Cevaluate_any_syneq_store >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      qx_gen_tac`se`>>strip_tac >>
      `fmap_rel (syneq FEMPTY) (store_to_Cstore m s3) se` by PROVE_TAC[fmap_rel_syneq_trans] >>
      BasicProvers.EVERY_CASE_TAC >>
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][]
      >- (
        disj2_tac >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        srw_tac[DNF_ss][] >>
        disj2_tac >>
        metis_tac[])
      >- (
        disj1_tac >>
        CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
        map_every qexists_tac[`w1`,`sd`] >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        disj2_tac >>
        Q.PAT_ABBREV_TAC`fv = fresh_var X` >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sd`,`enva`,`e2a`,`se`,`err`,`fv`,`w1`]mp_tac Cevaluate_FUPDATE_Rerr >>
        `fv ∉ free_vars FEMPTY e2a` by (
          unabbrev_all_tac >>
          match_mp_tac fresh_var_not_in_any >>
          rw[] ) >>
        simp[] >>
        PROVE_TAC[fmap_rel_syneq_trans])
      >- (
        disj2_tac >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        disj2_tac >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        rw[Once(CONJUNCT2(Cevaluate_cases))] >>
        srw_tac[DNF_ss][] >>
        disj2_tac >>
        PROVE_TAC[] )
      >- (
        disj1_tac >>
        CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
        map_every qexists_tac[`w1`,`sd`] >> fs[] >>
        rw[Once Cevaluate_cases] >>
        srw_tac[DNF_ss][] >>
        disj2_tac >>
        Q.PAT_ABBREV_TAC`fv = fresh_var X` >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sd`,`enva`,`e2a`,`se`,`err`,`fv`,`w1`]mp_tac Cevaluate_FUPDATE_Rerr >>
        `fv ∉ free_vars FEMPTY e2a` by (
          unabbrev_all_tac >>
          match_mp_tac fresh_var_not_in_any >>
          rw[] ) >>
        simp[] >>
        PROVE_TAC[fmap_rel_syneq_trans]))
    >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      disj2_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      srw_tac[DNF_ss][]>>
      disj2_tac >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac>>fs[]>>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >> rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w1)` >>
      pop_assum kall_tac >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sb enva e2a (sc,Rerr err)` >>
      pop_assum kall_tac >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        imp_res_tac v_to_Cv_closed >>
        fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva ∧
       free_vars FEMPTY e2a ⊆ FDOM enva` by (
        fs[Abbr`e1a`,Abbr`e2a`,Abbr`enva`,env_to_Cenv_MAP,MAP_MAP_o,
           pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair,FST_triple] ) >>
      `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
       (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
         unabbrev_all_tac >>
         fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
         rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >> fs[] >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(sc,Rerr err)`]mp_tac Cevaluate_any_syneq_store >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      qx_gen_tac`se`>>strip_tac >>
      PROVE_TAC[fmap_rel_syneq_trans] )
    >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][] >>
      disj2_tac >> disj1_tac >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac>>fs[]>>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >> rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w1)` >>
      pop_assum kall_tac >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sb enva e2a (sc,Rerr err)` >>
      pop_assum kall_tac >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        imp_res_tac v_to_Cv_closed >>
        fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva ∧
       free_vars FEMPTY e2a ⊆ FDOM enva` by (
        fs[Abbr`e1a`,Abbr`e2a`,Abbr`enva`,env_to_Cenv_MAP,MAP_MAP_o,
           pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair,FST_triple] ) >>
      `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
       (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
         unabbrev_all_tac >>
         fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
         rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >> fs[] >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(sc,Rerr err)`]mp_tac Cevaluate_any_syneq_store >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      PROVE_TAC[fmap_rel_syneq_trans])
    >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      disj2_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      srw_tac[DNF_ss][] >>
      disj2_tac >>
      qspecl_then[`cenv`,`s`,`env`,`e1`,`(s',Rval v1)`]mp_tac(CONJUNCT1 evaluate_closed) >>
      simp[]>>strip_tac>>fs[]>>
      rpt (first_x_assum (qspec_then `m` mp_tac)) >> rw[] >>
      qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v1) w1`[] >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w1)` >>
      pop_assum kall_tac >>
      qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sb enva e2a (sc,Rerr err)` >>
      pop_assum kall_tac >>
      `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
        imp_res_tac v_to_Cv_closed >>
        fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
      `free_vars FEMPTY e1a ⊆ FDOM enva ∧
       free_vars FEMPTY e2a ⊆ FDOM enva` by (
        fs[Abbr`e1a`,Abbr`e2a`,Abbr`enva`,env_to_Cenv_MAP,MAP_MAP_o,
           pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair,FST_triple] ) >>
      `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
       (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
         unabbrev_all_tac >>
         fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
         rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w1)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
      simp[] >> strip_tac >> fs[] >>
      qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(sc,Rerr err)`]mp_tac Cevaluate_any_syneq_store >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      PROVE_TAC[fmap_rel_syneq_trans])) >>
  strip_tac >- (
    ntac 2 gen_tac >>
    Cases >> fs[exp_to_Cexp_def] >>
    qx_gen_tac `e1` >>
    qx_gen_tac `e2` >>
    rw[LET_THM] >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      disj2_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      fsrw_tac[DNF_ss][])
    >- (
      BasicProvers.EVERY_CASE_TAC >>
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      fsrw_tac[DNF_ss][] >>
      disj2_tac >- (
        rw[Once(CONJUNCT2 Cevaluate_cases)] >>
        fsrw_tac[DNF_ss][] ) >>
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][] >>
      disj1_tac >>
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][] >>
      disj2_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      fsrw_tac[DNF_ss][])
    >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      disj2_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      fsrw_tac[DNF_ss][])
    >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD])
    >- (
      rw[Once Cevaluate_cases] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      disj2_tac >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      rw[Once(CONJUNCT2 Cevaluate_cases)] >>
      fsrw_tac[DNF_ss][]) ) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    imp_res_tac do_log_FV >>
    `FV exp' ⊆ set (MAP FST env)` by PROVE_TAC[SUBSET_TRANS] >>
    qspecl_then[`cenv`,`s`,`env`,`exp`,`(s',Rval v)`]mp_tac(CONJUNCT1 evaluate_closed) >>
    simp[]>>strip_tac>>fs[]>>
    rpt (first_x_assum (qspec_then`m` mp_tac)) >> rw[] >>
    qmatch_assum_rename_tac`syneq FEMPTY (v_to_Cv m v) w`[] >>
    qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w)` >>
    pop_assum kall_tac >>
    qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sb enva e2a (sc,w2)` >>
    ntac 2 (pop_assum kall_tac) >>
    `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
      imp_res_tac v_to_Cv_closed >>
      fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
    `free_vars FEMPTY e1a ⊆ FDOM enva ∧
     free_vars FEMPTY e2a ⊆ FDOM enva` by (
      fs[Abbr`e1a`,Abbr`e2a`,Abbr`enva`,env_to_Cenv_MAP,MAP_MAP_o,
         pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair,FST_triple] ) >>
    `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
     (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
       unabbrev_all_tac >>
       fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
       rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
    simp[] >> strip_tac >> fs[] >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(sc,w2)`]mp_tac Cevaluate_any_syneq_store >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    map_every qx_gen_tac[`se`,`w3`] >>strip_tac >>
    Cases_on `op` >> Cases_on `v` >> fs[do_log_def] >>
    Cases_on `l` >> fs[v_to_Cv_def] >>
    fs[Q.SPECL[`c`,`CLitv l`]syneq_cases] >> rw[] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][] >> disj1_tac >>
    CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
    map_every qexists_tac [`b`,`sd`] >> fs[] >>
    rw[] >> fs[] >> rw[] >>
    fs[evaluate_lit] >> rw[v_to_Cv_def] >>
    PROVE_TAC[result_rel_syneq_trans,fmap_rel_syneq_trans] ) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    Cases_on `op` >> fsrw_tac[DNF_ss][] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD]) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    imp_res_tac do_if_FV >>
    `FV exp' ⊆ set (MAP FST env)` by (
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      PROVE_TAC[]) >> fs[] >>
    qspecl_then[`cenv`,`s`,`env`,`exp`,`(s',Rval v)`]mp_tac(CONJUNCT1 evaluate_closed) >>
    simp[]>>strip_tac>>fs[]>>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][] >>
    disj1_tac >>
    rpt (first_x_assum (qspec_then`m` mp_tac)) >> rw[] >>
    qmatch_assum_rename_tac`syneq FEMPTY (v_to_Cv m v) w`[] >>
    qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sa enva e1a (sd,Rval w)` >>
    pop_assum kall_tac >>
    qmatch_assum_abbrev_tac `Cevaluate FEMPTY FEMPTY sb enva e2a (sc,w2)` >>
    ntac 2 (pop_assum kall_tac) >>
    `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
      imp_res_tac v_to_Cv_closed >>
      fs[FEVERY_DEF] >> PROVE_TAC[] ) >>
    `free_vars FEMPTY e1a ⊆ FDOM enva ∧
     free_vars FEMPTY e2a ⊆ FDOM enva` by (
      fs[Abbr`e1a`,Abbr`e2a`,Abbr`enva`,env_to_Cenv_MAP,MAP_MAP_o,
         pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair,FST_triple] ) >>
    `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
     (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
       unabbrev_all_tac >>
       fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
       rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`e1a`,`(sd,Rval w)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
    simp[] >> strip_tac >> fs[] >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`e2a`,`(sc,w2)`]mp_tac Cevaluate_any_syneq_store >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    map_every qx_gen_tac[`se`,`w3`] >>strip_tac >>
    CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
    CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`sd` >>
    CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`w3` >>
    CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`se` >>
    qpat_assum `do_if v e2 e3 = X` mp_tac >>
    fs[do_if_def] >> rw[] >|[
      qexists_tac`T`,
      qexists_tac`F`] >>
    fsrw_tac[DNF_ss][v_to_Cv_def,Q.SPECL[`c`,`CLitv l`]syneq_cases] >>
    PROVE_TAC[fmap_rel_syneq_trans,result_rel_syneq_trans]) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >> fs[] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD]) >>
  strip_tac >- (
    rpt strip_tac >> fs[] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    first_x_assum (qspec_then `m` mp_tac) >> rw[] >>
    qmatch_assum_rename_tac `syneq FEMPTY (v_to_Cv m v) w`[] >>
    rw[exp_to_Cexp_def,LET_THM] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][] >>
    disj1_tac >>
    qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva ea (sd,Rval w)` >>
    pop_assum kall_tac >>
    CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
    map_every qexists_tac [`w`,`sd`] >> fs[] >>
    qmatch_assum_abbrev_tac `evaluate_match_with P cenv s2 env v pes res` >>
    Q.ISPECL_THEN [`s2`,`pes`,`res`] mp_tac (Q.GEN`s`evaluate_match_with_matchres) >> fs[] >>
    PairCases_on`res`>>fs[]>>strip_tac>>
    qmatch_assum_abbrev_tac`evaluate_match_with (matchres env) cenv s2 env v pes r` >>
    Q.ISPECL_THEN [`s2`,`pes`,`r`] mp_tac (Q.GEN`s`evaluate_match_with_Cevaluate_match) >>
    fs[Abbr`r`] >>
    disch_then (qspec_then `m` mp_tac) >>
    rw[] >- (
      qmatch_assum_abbrev_tac `Cevaluate_match sb vv ppes FEMPTY NONE` >>
      `Cevaluate_match sb vv (MAP (λ(p,e). (p, exp_to_Cexp m e)) ppes) FEMPTY NONE` by (
        metis_tac [Cevaluate_match_MAP_exp, optionTheory.OPTION_MAP_DEF] ) >>
      qmatch_assum_abbrev_tac `Cevaluate_match sb vv (MAP ff ppes) FEMPTY NONE` >>
      `MAP ff ppes = pes_to_Cpes m pes` by (
        unabbrev_all_tac >>
        rw[pes_to_Cpes_MAP,LET_THM] >>
        rw[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
        rw[pairTheory.UNCURRY] ) >>
      fs[] >>
      map_every qunabbrev_tac[`ppes`,`ff`,`vv`] >>
      pop_assum kall_tac >>
      ntac 2 (pop_assum mp_tac) >>
      pop_assum kall_tac >>
      ntac 2 strip_tac >>
      Q.SPECL_THEN [`sb`,`v_to_Cv m v`,`pes_to_Cpes m pes`,`FEMPTY`,`NONE`]
        mp_tac (INST_TYPE[alpha|->``:Cexp``](Q.GENL[`v`,`s`] Cevaluate_match_syneq)) >>
      fs[] >>
      disch_then (qspecl_then [`FEMPTY`,`sd`,`w`] mp_tac) >> fs[] >>
      strip_tac >>
      qabbrev_tac`ps = pes_to_Cpes m pes` >>
      qspecl_then[`sd`,`w`,`ps`,`FEMPTY`,`NONE`]mp_tac(Q.GENL[`v`,`s`]Cevaluate_match_remove_mat_var)>>
      fs[] >>
      fsrw_tac[DNF_ss][EXISTS_PROD] >>
      Q.PAT_ABBREV_TAC`envu = enva |+ X` >>
      Q.PAT_ABBREV_TAC`fv = fresh_var X` >>
      disch_then (qspecl_then[`envu`,`fv`]mp_tac)>>
      qmatch_abbrev_tac`(P0 ⇒ Q) ⇒ R` >>
      `P0` by (
        map_every qunabbrev_tac[`P0`,`Q`,`R`] >>
        fs[FLOOKUP_UPDATE,Abbr`envu`] >>
        fsrw_tac[DNF_ss][pairTheory.FORALL_PROD] >>
        conj_tac >- (
          qx_gen_tac `z` >>
          Cases_on `fv ∈ z` >> fs[] >>
          qx_gen_tac `p` >>
          qx_gen_tac `e` >>
          Cases_on `z = Cpat_vars p` >> fs[] >>
          spose_not_then strip_assume_tac >>
          `fv ∉ Cpat_vars p` by (
            unabbrev_all_tac >>
            match_mp_tac fresh_var_not_in_any >>
            rw[Cpes_vars_thm] >> rw[] >>
            srw_tac[DNF_ss][SUBSET_DEF,pairTheory.EXISTS_PROD,MEM_MAP] >>
            metis_tac[] ) ) >>
        conj_tac >- (
          unabbrev_all_tac >>
          fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_pair,FST_triple] >>
          fsrw_tac[DNF_ss][SUBSET_DEF,pairTheory.FORALL_PROD,pes_to_Cpes_MAP,MEM_MAP,LET_THM,pairTheory.EXISTS_PROD] >>
          fsrw_tac[DNF_ss][pairTheory.UNCURRY,Cpes_vars_thm] >>
          metis_tac[Cpat_vars_pat_to_Cpat,pairTheory.pair_CASES,pairTheory.SND] ) >>
        `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
          unabbrev_all_tac >>
          fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
          rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
        `free_vars FEMPTY ea ⊆ FDOM enva` by (
          unabbrev_all_tac >>
          fs[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,LAMBDA_PROD,FST_pair,FST_triple]) >>
        `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
          unabbrev_all_tac >>
          match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
          fsrw_tac[DNF_ss][MEM_MAP,FORALL_PROD,env_to_Cenv_MAP,EVERY_MEM] >>
          rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
        qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`ea`,`(sd,Rval w)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
        simp[] >> strip_tac >>
        match_mp_tac IN_FRANGE_DOMSUB_suff >>
        rw[] ) >>
      simp[] >>
      map_every qunabbrev_tac[`P0`,`Q`,`R`] >>
      metis_tac[fmap_rel_syneq_trans,fmap_rel_syneq_sym] ) >>
    qmatch_assum_abbrev_tac `Cevaluate_match sb vv ppes eenv (SOME mr)` >>
    `Cevaluate_match sb vv (MAP (λ(p,e). (p, exp_to_Cexp m e)) ppes) eenv (SOME (exp_to_Cexp m mr))` by (
      metis_tac [Cevaluate_match_MAP_exp, optionTheory.OPTION_MAP_DEF] ) >>
    pop_assum mp_tac >>
    map_every qunabbrev_tac[`ppes`,`eenv`,`vv`] >>
    pop_assum mp_tac >>
    pop_assum kall_tac >>
    ntac 2 strip_tac >>
    qmatch_assum_abbrev_tac `Cevaluate_match sb vv (MAP ff ppes) eenv mmr` >>
    `MAP ff ppes = pes_to_Cpes m pes` by (
      unabbrev_all_tac >>
      rw[pes_to_Cpes_MAP,LET_THM] >>
      rw[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
      rw[pairTheory.UNCURRY] ) >>
    fs[] >>
    pop_assum kall_tac >>
    qunabbrev_tac `ppes` >>
    qabbrev_tac`ps = pes_to_Cpes m pes` >>
    Q.ISPECL_THEN[`sb`,`vv`,`ps`,`eenv`,`mmr`]mp_tac(Q.GENL[`v`,`s`]Cevaluate_match_syneq) >>
    simp[] >>
    disch_then(qspecl_then[`FEMPTY`,`sd`,`w`]mp_tac) >>
    simp[] >>
    disch_then(Q.X_CHOOSE_THEN`wenv`strip_assume_tac) >>
    qspecl_then[`sd`,`w`,`ps`,`wenv`,`mmr`]mp_tac(Q.GENL[`v`,`s`]Cevaluate_match_remove_mat_var) >>
    simp[Abbr`mmr`] >>
    Q.PAT_ABBREV_TAC`fv = fresh_var X` >>
    fsrw_tac[DNF_ss][FORALL_PROD,EXISTS_PROD] >>
    disch_then(qspecl_then[`enva|+(fv,w)`,`fv`]mp_tac) >>
    qspecl_then[`cenv`,`s`,`env`,`exp`,`(s2,Rval v)`]mp_tac(CONJUNCT1 evaluate_closed) >>
    simp[] >> strip_tac >>
    Q.ISPECL_THEN[`s2`,`pes`,`(s2,Rval(menv,mr))`]mp_tac(Q.GEN`s`evaluate_match_with_matchres_closed)>>
    simp[] >> strip_tac >>
    `FV mr ⊆ set (MAP FST (menv ++ env))` by (
      fsrw_tac[DNF_ss][SUBSET_DEF,FORALL_PROD,MEM_MAP,EXISTS_PROD] >>
      pop_assum mp_tac >>
      simp[EXTENSION] >>
      fsrw_tac[DNF_ss][MEM_MAP,EXISTS_PROD] >>
      METIS_TAC[] ) >>
    fs[Abbr`P`] >> rfs[] >> fs[] >>
    first_x_assum(qspec_then`m`mp_tac)>>
    fsrw_tac[DNF_ss][] >>
    qpat_assum`evaluate_match_with P cenv s2 env v pes (res0,res1)`kall_tac >>
    map_every qx_gen_tac [`se`,`re`] >> strip_tac >>
    qabbrev_tac`emr = exp_to_Cexp m mr` >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`eenv ⊌ enva`,`wenv ⊌ enva`,`emr`,`(se,re)`]mp_tac Cevaluate_any_syneq_any >>
    `∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
      rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
    `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >>
      match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
      fsrw_tac[DNF_ss][env_to_Cenv_MAP,MEM_MAP,FORALL_PROD,EVERY_MEM] >>
      rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
    `free_vars FEMPTY ea ⊆ FDOM enva` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][env_to_Cenv_MAP,SUBSET_DEF,MEM_MAP,FORALL_PROD,EXISTS_PROD]) >>
    `∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
      rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`ea`,`(sd,Rval w)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
    simp[] >> strip_tac >>
    qspecl_then[`FEMPTY`,`sd`,`w`,`ps`,`wenv`,`SOME emr`]mp_tac
      (INST_TYPE[alpha|->``:Cexp``](Q.GENL[`v`,`s`,`c`]Cevaluate_match_closed)) >>
    simp[] >> strip_tac >>
    `∀v. v ∈ FRANGE eenv ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >>
      match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
      fsrw_tac[DNF_ss][env_to_Cenv_MAP,MEM_MAP,EVERY_MEM,FORALL_PROD,EXISTS_PROD] >>
      rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
    qmatch_abbrev_tac`(P ⇒ Q) ⇒ R` >>
    `P` by (
      map_every qunabbrev_tac[`P`,`Q`,`R`] >>
      conj_tac >- (
        match_mp_tac fmap_rel_FUNION_rels >> rw[] ) >>
      conj_tac >- (
        match_mp_tac IN_FRANGE_FUNION_suff >> rw[] ) >>
      conj_tac >- (
        unabbrev_all_tac >>
        rw[env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,UNCURRY] >>
        srw_tac[ETA_ss][] ) >>
      match_mp_tac IN_FRANGE_FUNION_suff >> rw[] ) >>
    simp[] >>
    map_every qunabbrev_tac[`P`,`Q`,`R`] >>
    fsrw_tac[DNF_ss][FORALL_PROD] >>
    map_every qx_gen_tac[`sf`,`rf`] >> strip_tac >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sd`,`wenv ⊌ enva`,`emr`,`(sf,rf)`,`fv`,`w`]mp_tac Cevaluate_FUPDATE >>
    `fv ∉ free_vars FEMPTY emr` by (
      unabbrev_all_tac >>
      match_mp_tac fresh_var_not_in_any >>
      fsrw_tac[DNF_ss][SUBSET_DEF,Cpes_vars_thm,pes_to_Cpes_MAP,LET_THM,MEM_MAP,
                       UNCURRY,EXISTS_PROD,FORALL_PROD] >>
      fsrw_tac[DNF_ss][env_to_Cenv_MAP,MEM_MAP,EXISTS_PROD] >>
      PROVE_TAC[] ) >>
    `FDOM wenv = FDOM eenv` by fs[fmap_rel_def] >>
    fsrw_tac[DNF_ss][FORALL_PROD] >>
    map_every qx_gen_tac[`sg`,`rg`] >> strip_tac >>
    `(wenv ⊌ enva) |+ (fv,w) = wenv ⊌ enva |+ (fv,w)` by (
      `fv ∉ FDOM eenv` by (
        unabbrev_all_tac >>
        match_mp_tac fresh_var_not_in_any >>
        fs[fmap_rel_def] >>
        fsrw_tac[DNF_ss][Cpes_vars_thm] >>
        `set (MAP FST (env_to_Cenv m menv)) = Cpat_vars (SND (pat_to_Cpat m [] p))` by (
          fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,pairTheory.LAMBDA_PROD,combinTheory.o_DEF,FST_pair,FST_triple] >>
          METIS_TAC[Cpat_vars_pat_to_Cpat,pairTheory.SND,pairTheory.pair_CASES] ) >>
        fs[] >>
        fsrw_tac[DNF_ss][SUBSET_DEF,pes_to_Cpes_MAP,MEM_MAP,LET_THM] >>
        qpat_assum `MEM (p,x) pes` mp_tac >>
        rpt (pop_assum kall_tac) >>
        fsrw_tac[DNF_ss][pairTheory.EXISTS_PROD,pairTheory.UNCURRY] >>
        METIS_TAC[Cpat_vars_pat_to_Cpat,pairTheory.SND,pairTheory.pair_CASES] ) >>
      rw[FUNION_FUPDATE_2] ) >>
    disch_then(qspecl_then[`sg`,`rg`]mp_tac)>> fs[] >>
    qmatch_abbrev_tac`(P ⇒ Q) ⇒ R` >>
    `P` by (
      map_every qunabbrev_tac[`P`,`Q`,`R`] >>
      simp[FLOOKUP_UPDATE] >>
      conj_tac >- (
        spose_not_then strip_assume_tac >>
        unabbrev_all_tac >> rw[] >>
        qpat_assum`fresh_var X ∈ Y`mp_tac >>
        simp[] >>
        match_mp_tac fresh_var_not_in_any >>
        fsrw_tac[DNF_ss][SUBSET_DEF,Cpes_vars_thm,MEM_MAP,pes_to_Cpes_MAP,LET_THM,UNCURRY] >>
        PROVE_TAC[] ) >>
      conj_tac >- (
        unabbrev_all_tac >>
        fsrw_tac[DNF_ss][SUBSET_DEF,pes_to_Cpes_MAP,env_to_Cenv_MAP,MEM_MAP,LET_THM,UNCURRY] >>
        PROVE_TAC[] ) >>
      match_mp_tac IN_FRANGE_DOMSUB_suff >>
      rw[] ) >>
    simp[] >>
    map_every qunabbrev_tac[`P`,`Q`,`R`] >>
    metis_tac[result_rel_syneq_trans,result_rel_syneq_sym,
              fmap_rel_syneq_sym,fmap_rel_syneq_trans]) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD]) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][bind_def,EXISTS_PROD] >>
    disj1_tac >>
    qspecl_then[`cenv`,`s`,`env`,`exp`,`(s',Rval v)`]mp_tac(CONJUNCT1 evaluate_closed) >>
    simp[] >> strip_tac >> fs[] >>
    rpt (first_x_assum (qspec_then `m` mp_tac)) >>
    rw[] >>
    qmatch_assum_rename_tac`syneq FEMPTY (v_to_Cv m v) w`[] >>
    pop_assum mp_tac >>
    Q.PAT_ABBREV_TAC`P = X ⊆ Y` >>
    `P` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][SUBSET_DEF] >>
      METIS_TAC[] ) >>
    simp[] >> qunabbrev_tac`P` >>
    qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva ea (sd,Rval w)` >>
    pop_assum kall_tac >>
    fsrw_tac[DNF_ss][] >>
    map_every qx_gen_tac[`se`,`re`] >>
    strip_tac >>
    qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sb envb eb (se,re)` >>
    CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
    map_every qexists_tac[`w`,`sd`] >>
    rw[] >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`envb`,`enva |+ (n,w)`,`eb`,`(se,re)`]mp_tac Cevaluate_any_syneq_any >>
    `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
     (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
      rw[] >> match_mp_tac(CONJUNCT1 v_to_Cv_closed) >> res_tac) >>
    `(free_vars FEMPTY ea ⊆ FDOM enva) ∧
     (free_vars FEMPTY eb ⊆ FDOM envb)` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,SUBSET_DEF,MEM_MAP,FORALL_PROD,EXISTS_PROD]) >>
    `(∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v) ∧
     (∀v. v ∈ FRANGE envb ⇒ Cclosed FEMPTY v)` by (
      unabbrev_all_tac >> conj_tac >>
      match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
      fsrw_tac[DNF_ss][MEM_MAP,env_to_Cenv_MAP,FORALL_PROD,EVERY_MEM] >>
      rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac >> fs[] ) >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`ea`,`(sd,Rval w)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
    simp[] >> strip_tac >>
    qmatch_abbrev_tac`(P ⇒ Q) ⇒ R` >>
    `P` by (
      unabbrev_all_tac >>
      conj_tac >- (
        rw[fmap_rel_def,env_to_Cenv_MAP,FAPPLY_FUPDATE_THM] >>
        rw[] ) >>
      fsrw_tac[DNF_ss][] >>
      match_mp_tac IN_FRANGE_DOMSUB_suff >>
      simp[] ) >>
    simp[] >>
    unabbrev_all_tac >>
    fsrw_tac[DNF_ss][FORALL_PROD] >>
    metis_tac[result_rel_syneq_trans,fmap_rel_syneq_trans] ) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM] >>
    rw[Once Cevaluate_cases] >>
    fsrw_tac[DNF_ss][EXISTS_PROD]) >>
  strip_tac >- (
    rw[exp_to_Cexp_def,LET_THM,FST_triple] >>
    fs[] >>
    rw[defs_to_Cdefs_MAP] >>
    rw[Once Cevaluate_cases,FOLDL_FUPDATE_LIST] >>
    `FV exp ⊆ set (MAP FST funs) ∪ set (MAP FST env)` by (
      fsrw_tac[DNF_ss][SUBSET_DEF,pairTheory.FORALL_PROD,MEM_MAP,pairTheory.EXISTS_PROD] >>
      METIS_TAC[] ) >>
    fs[] >>
    `EVERY closed (MAP (FST o SND) (build_rec_env tvs funs env))` by (
      match_mp_tac build_rec_env_closed >>
      fs[] >>
      fsrw_tac[DNF_ss][SUBSET_DEF,pairTheory.FORALL_PROD,MEM_MAP,pairTheory.EXISTS_PROD,MEM_EL,FST_5tup] >>
      METIS_TAC[] ) >>
    fs[] >>
    first_x_assum (qspec_then `m` mp_tac) >>
    fs[] >>
    simp_tac std_ss [build_rec_env_def,bind_def,FOLDR_CONS_5tup] >>
    fsrw_tac[DNF_ss][EXISTS_PROD,FORALL_PROD] >>
    simp_tac std_ss [FUNION_alist_to_fmap] >>
    Q.PAT_ABBREV_TAC`ee = alist_to_fmap (env_to_Cenv X Y)` >>
    simp_tac (srw_ss()) [env_to_Cenv_MAP,MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD] >>
    simp_tac (srw_ss()) [v_to_Cv_def,LET_THM,pairTheory.UNCURRY,defs_to_Cdefs_MAP] >>
    Q.PAT_ABBREV_TAC`ls:(string#Cv) list = MAP f funs` >>
    `ALL_DISTINCT (MAP FST ls)` by (
      unabbrev_all_tac >>
      rw[MAP_MAP_o,combinTheory.o_DEF,pairTheory.LAMBDA_PROD,FST_triple] ) >>
    rw[FUPDATE_LIST_ALL_DISTINCT_REVERSE] >>
    rw[MEM_MAP,FORALL_PROD,EXISTS_PROD] >>
    fs[FST_5tup] >>
    qmatch_assum_rename_tac `Cevaluate FEMPTY FEMPTY X Y Z (p1,p2)`["X","Y","Z"] >>
    map_every qexists_tac[`p1`,`p2`] >>
    reverse conj_tac >- METIS_TAC[] >>
    reverse conj_tac >- METIS_TAC[] >>
    spose_not_then strip_assume_tac >>
    pop_assum mp_tac >> rw[EL_MAP,UNCURRY]) >>
  strip_tac >- rw[] >>
  strip_tac >- (
    rw[] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    rw[Once Cevaluate_cases] ) >>
  strip_tac >- (
    rw[] >>
    rw[Once (CONJUNCT2 Cevaluate_cases)] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] >>
    qspecl_then[`cenv`,`s`,`env`,`exp`,`(s',Rval v)`]mp_tac(CONJUNCT1 evaluate_closed) >>
    simp[] >> strip_tac >> fs[] >>
    rpt (first_x_assum (qspec_then`m` mp_tac)) >>
    rw[] >>
    qmatch_assum_rename_tac`syneq FEMPTY (v_to_Cv m v) w`[] >>
    qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva ea (sd,Rval w)` >>
    pop_assum kall_tac >>
    CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`sd` >>
    CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`w` >> rw[] >>
    qmatch_assum_abbrev_tac`Cevaluate_list FEMPTY FEMPTY sb enva eb (se,Rval ws)` >>
    ntac 2 (pop_assum kall_tac) >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`enva`,`eb`,`(se,Rval ws)`]mp_tac Cevaluate_list_any_syneq_any >>
    `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
      unabbrev_all_tac >>
      match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
      fsrw_tac[DNF_ss][MEM_MAP,env_to_Cenv_MAP,EVERY_MEM,FORALL_PROD] >>
      rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
    `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
     (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
      rw[] >> match_mp_tac(CONJUNCT1 v_to_Cv_closed) >> res_tac) >>
    `(free_vars FEMPTY ea ⊆ FDOM enva) ∧
     (BIGUNION (IMAGE (free_vars FEMPTY) (set eb)) ⊆ FDOM enva)` by (
      unabbrev_all_tac >>
      fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,SUBSET_DEF,MEM_MAP,FORALL_PROD,EXISTS_PROD]) >>
    qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`ea`,`(sd,Rval w)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
    simp[] >> strip_tac >>
    fsrw_tac[DNF_ss][FORALL_PROD] >>
    map_every qx_gen_tac[`sf`,`rf`] >>
    strip_tac >>
    map_every qexists_tac[`sf`,`rf`] >>
    simp[] >>
    conj_tac >- METIS_TAC[fmap_rel_syneq_trans] >>
    fsrw_tac[DNF_ss][EVERY2_EVERY,EVERY_MEM,FORALL_PROD,MEM_ZIP] >>
    `LENGTH vs = LENGTH ws` by rw[] >>
    qpat_assum `LENGTH ws = LENGTH rf` assume_tac >>
    fsrw_tac[DNF_ss][MEM_ZIP] >>
    rw[EL_MAP] >>
    rpt (first_x_assum (qspec_then`n`mp_tac)) >>
    rw[EL_MAP] >>
    METIS_TAC[syneq_trans] ) >>
  strip_tac >- (
    rw[] >>
    rw[Once (CONJUNCT2 Cevaluate_cases)] >>
    fsrw_tac[DNF_ss][EXISTS_PROD] ) >>
  rw[] >>
  rw[Once (CONJUNCT2 Cevaluate_cases)] >>
  fsrw_tac[DNF_ss][EXISTS_PROD] >>
  disj2_tac >>
  qspecl_then[`cenv`,`s`,`env`,`exp`,`(s',Rval v)`]mp_tac(CONJUNCT1 evaluate_closed) >>
  simp[] >> strip_tac >> fs[] >>
  rpt (first_x_assum (qspec_then`m` mp_tac)) >>
  rw[] >>
  qmatch_assum_rename_tac`syneq FEMPTY (v_to_Cv m v) w`[] >>
  qmatch_assum_abbrev_tac`Cevaluate FEMPTY FEMPTY sa enva ea (sd,Rval w)` >>
  pop_assum kall_tac >>
  CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`sd` >>
  CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`w` >> rw[] >>
  qmatch_assum_abbrev_tac`Cevaluate_list FEMPTY FEMPTY sb enva eb (se,Rerr err)` >>
  pop_assum kall_tac >>
  qspecl_then[`FEMPTY`,`FEMPTY`,`sb`,`sd`,`enva`,`enva`,`eb`,`(se,Rerr err)`]mp_tac Cevaluate_list_any_syneq_any >>
  `∀v. v ∈ FRANGE enva ⇒ Cclosed FEMPTY v` by (
    unabbrev_all_tac >>
    match_mp_tac IN_FRANGE_alist_to_fmap_suff >>
    fsrw_tac[DNF_ss][MEM_MAP,env_to_Cenv_MAP,EVERY_MEM,FORALL_PROD] >>
    rw[] >> match_mp_tac (CONJUNCT1 v_to_Cv_closed) >> res_tac ) >>
  `(∀v. v ∈ FRANGE sa ⇒ Cclosed FEMPTY v) ∧
   (∀v. v ∈ FRANGE sb ⇒ Cclosed FEMPTY v)` by (
    unabbrev_all_tac >>
    fsrw_tac[DNF_ss][FRANGE_store_to_Cstore,MEM_MAP,EVERY_MEM] >>
    rw[] >> match_mp_tac(CONJUNCT1 v_to_Cv_closed) >> res_tac) >>
  `(free_vars FEMPTY ea ⊆ FDOM enva) ∧
   (BIGUNION (IMAGE (free_vars FEMPTY) (set eb)) ⊆ FDOM enva)` by (
    unabbrev_all_tac >>
    fsrw_tac[DNF_ss][env_to_Cenv_MAP,MAP_MAP_o,SUBSET_DEF,MEM_MAP,FORALL_PROD,EXISTS_PROD]) >>
  qspecl_then[`FEMPTY`,`FEMPTY`,`sa`,`enva`,`ea`,`(sd,Rval w)`]mp_tac(CONJUNCT1 Cevaluate_closed) >>
  simp[] >> strip_tac >>
  fsrw_tac[DNF_ss][FORALL_PROD] >>
  METIS_TAC[fmap_rel_syneq_trans])

val _ = export_theory()
