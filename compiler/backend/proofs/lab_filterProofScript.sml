open preamble labSemTheory labPropsTheory lab_filterTheory;
open BasicProvers

val _ = new_theory "lab_filterProof";

val adjust_pc_def = Define `
  adjust_pc p xs =
    if p = 0n then 0n else
      case xs of
      | [] => p
      | (Section n [] :: rest) => adjust_pc p rest
      | (Section n (l::lines) :: rest) =>
          if is_Label l then
            adjust_pc p (Section n lines :: rest)
          else if not_skip l then
            adjust_pc (p-1) (Section n lines :: rest) + 1
          else adjust_pc (p-1) (Section n lines :: rest)`

(*All skips for the next k*)
val all_skips_def = Define`
  all_skips pc code k ⇔
  (∀x y. asm_fetch_aux (pc+k) code ≠ SOME(Asm (Inst Skip) x y)) ∧
  ∀i. i < k ⇒
    ∃x y.
    asm_fetch_aux (pc+i) code = SOME(Asm (Inst Skip) x y)`

val is_Label_not_skip = prove(``
  is_Label y ⇒ not_skip y``,
  Cases_on`y`>>fs[is_Label_def,not_skip_def])

(*
Proof plan:
1)
For any pc, code,
there exists a k such that
asmfetch (pc+k) code = asmfetch (adjust pc) (adjust code)
and
for all i < k
  asmfetch (pc+i) code = Skip

2)
for all i < k.
  asmfetch(pc+i) code = Skip
⇒
evaluate pc code with k for a clock = evaluate (pc+k) code

*)

(* 1)
There is probably a neater way to prove this*)
val asm_fetch_aux_eq = prove(``
  ∀pc code.
  ∃k.
    asm_fetch_aux (pc+k) code = asm_fetch_aux (adjust_pc pc code) (filter_skip code) ∧
    all_skips pc code k``,
  Induct_on`code`
  >-
    (simp[Once adjust_pc_def,filter_skip_def,asm_fetch_aux_def,all_skips_def]>>
    qexists_tac`0`>>DECIDE_TAC)
  >>
  Induct_on`h`>>Induct_on`l`>>fs[]>>rw[]
  >-
    (Cases_on`pc=0`>>simp[asm_fetch_aux_def,Once adjust_pc_def,filter_skip_def]
    >-
      (first_x_assum(qspec_then`0`assume_tac)>>
      fs[all_skips_def,asm_fetch_aux_def]>>
      qexists_tac`k`>>fs[Once adjust_pc_def])
    >>
      fs[all_skips_def]>>fs[Once asm_fetch_aux_def]>>
      first_x_assum(qspec_then`pc` assume_tac)>>fs[]>>
      metis_tac[DECIDE``A +B = B+A:num``,asm_fetch_aux_def])
  >>
  Cases_on`pc=0`
  >-
    (Cases_on`h`>>fs[asm_fetch_aux_def,is_Label_def,filter_skip_def,not_skip_def,all_skips_def]
    >-
      (first_x_assum(qspecl_then[`n`,`0`] assume_tac)>>
      fs[]>>
      qexists_tac`k`>>ntac 2 (simp[Once adjust_pc_def]))
    >-
      (first_x_assum(qspecl_then[`n`,`0`] assume_tac)>>
      fs[]>>
      EVERY_CASE_TAC>>fs[]>>
      fs[Once adjust_pc_def,asm_fetch_aux_def]
      >-
        (qexists_tac`k+1`>>rfs[]>>rw[]>>
        `i-1<k` by DECIDE_TAC>>
        metis_tac[])
      >>
      qexists_tac`0`>>fs[]>>
      simp[Once adjust_pc_def]>>
      simp[Once asm_fetch_aux_def,SimpRHS,is_Label_def])
    >-
      (qexists_tac`0`>>fs[is_Label_def]>>
      simp[Once adjust_pc_def]))
  >>
  Cases_on`h`>>
  simp[Once adjust_pc_def]>>
  fs[asm_fetch_aux_def,is_Label_def,filter_skip_def,not_skip_def,all_skips_def]
  >-
    metis_tac[DECIDE``A+B = B+A:num``]
  >>
    (EVERY_CASE_TAC>>fs[]>>
    simp[Once asm_fetch_aux_def,SimpRHS,is_Label_def]>>
    first_x_assum(qspecl_then[`n`,`pc-1`] assume_tac)>>fs[]>>
    `∀x. pc - 1 + x = pc + x -1` by DECIDE_TAC>>
    `∀x. pc - 1 + x = x + pc -1` by DECIDE_TAC>>
    metis_tac[]))

(*For any adjusted fetch, the original fetch is either equal or is a skip
This is probably the wrong direction*)
val asm_fetch_not_skip_adjust_pc = prove(
  ``∀pc code inst.
  (∀x y.asm_fetch_aux pc code ≠ SOME (Asm (Inst Skip) x y)) ⇒
  asm_fetch_aux pc code = asm_fetch_aux (adjust_pc pc code) (filter_skip code)``,
  ho_match_mp_tac asm_fetch_aux_ind>>rw[]
  >-
    simp[asm_fetch_aux_def,filter_skip_def]
  >-
    (fs[asm_fetch_aux_def,filter_skip_def]>>
    simp[Once adjust_pc_def,SimpRHS]>>
    IF_CASES_TAC>>
    metis_tac[adjust_pc_def])
  >>
  Cases_on`is_Label y`>>fs[]
  >-
    (fs[asm_fetch_aux_def,filter_skip_def]>>
    simp[Once adjust_pc_def,SimpRHS]>>
    simp[is_Label_not_skip]>>
    IF_CASES_TAC>>
    res_tac>>fs[]>>
    simp[asm_fetch_aux_def]>>
    simp[Once adjust_pc_def])
  >>
  reverse(Cases_on`pc ≠ 0`>>fs[])
  >-
    (fs[asm_fetch_aux_def,Once adjust_pc_def,filter_skip_def,not_skip_def]>>
    EVERY_CASE_TAC>>
    fs[asm_fetch_aux_def,is_Label_def])
  >>
    fs[Once asm_fetch_aux_def]>>
    simp[Once adjust_pc_def,SimpRHS]>>
    IF_CASES_TAC>>fs[filter_skip_def]>>
    simp[asm_fetch_aux_def])

val state_rw = prove(``
  s with clock := s.clock = s ∧
  s with pc := s.pc = s ∧
  s with <|pc := s.pc; clock:= s.clock+k'|> = s with clock:=s.clock+k'``,
  fs[state_component_equality])

(* 2) all_skips allow swapping pc for clock*)
val all_skips_evaluate = prove(``
  ∀k s.
  all_skips s.pc s.code k ∧
  ¬s.failed ⇒
  ∀k'.
  evaluate (s with clock:= s.clock +k' + k) =
  evaluate (s with <|pc := s.pc +k; clock:= s.clock +k'|>)``,
  Induct>>fs[all_skips_def]
  >-
    metis_tac[state_rw]
  >>
    rw[]>>first_assum(qspec_then`0` mp_tac)>>
    discharge_hyps>-
      fs[]>>
    strip_tac>>fs[]>>
    simp[Once evaluate_def,asm_fetch_def,asm_inst_def]>>
    fs[inc_pc_def,dec_clock_def]>>
    fs[arithmeticTheory.ADD1]>>
    `k' + (k+1 + s.clock) -1 = k' + s.clock+k` by DECIDE_TAC>>
    fs[]>>
    first_x_assum(qspec_then `s with <|pc:=s.pc+1;clock:=k'+s.clock|>` mp_tac)>>
    discharge_hyps>-
      (rw[]>>first_x_assum(qspec_then`i+1` assume_tac)>>rfs[]>>
      metis_tac[arithmeticTheory.ADD_COMM,ADD_ASSOC])>>
    rw[]>>first_x_assum(qspec_then`0` assume_tac)>>rfs[]>>
    metis_tac[arithmeticTheory.ADD_COMM,ADD_ASSOC])

val state_rel_def = Define `
  state_rel (s1:('a,'ffi) labSem$state) t1 =
    (s1 = t1 with <| code := filter_skip t1.code ;
                     pc := adjust_pc t1.pc t1.code |>)`

val adjust_pc_all_skips = prove(``
  ∀k pc code.
  all_skips pc code k ⇒
  adjust_pc pc code +1 = adjust_pc (pc+k+1) code``,
  Induct>>fs[all_skips_def]>>simp[]>>
  ho_match_mp_tac asm_fetch_aux_ind
  >>
  fs[asm_fetch_aux_def]>>rw[]>>simp[Once adjust_pc_def,SimpRHS]>>
  simp[Once adjust_pc_def]>>
  TRY (IF_CASES_TAC>>fs[not_skip_def]>>
      fs[Once adjust_pc_def]>>
      pop_assum mp_tac >> EVERY_CASE_TAC>>fs[]>>NO_TAC)
  >-
    (IF_CASES_TAC>>fs[]>>
    `pc - 1 + 1 = pc` by DECIDE_TAC>>
    fs[])
  >-
    (pop_assum(qspec_then`k` mp_tac)>>fs[])
  >>
    fs[arithmeticTheory.ADD1]>>Cases_on`pc=0`
    >-
      (first_assum(qspec_then`0` mp_tac)>>
      fs[]>>discharge_hyps>-DECIDE_TAC>>strip_tac>>
      fs[not_skip_def]>>
      first_x_assum(qspecl_then[`0`,`Section k' ys::xs`]mp_tac)>>discharge_hyps>-
      (fs[]>>rw[]>>
      first_x_assum(qspec_then`i+1` mp_tac)>>discharge_hyps>-DECIDE_TAC>>
      rw[])>>
      fs[Once adjust_pc_def])
    >>
    fs[]>>IF_CASES_TAC>>fs[]>>
    `pc -1 + (k+1 +1) = pc +(k+1)` by DECIDE_TAC>>
    `pc -1 + (k+1) = pc + k` by DECIDE_TAC>>
    `pc  + (k+1) -1 = pc + k` by DECIDE_TAC>>
    `!i. i+(pc-1) = i+pc -1` by DECIDE_TAC>>
    fs[]>>
    first_assum match_mp_tac>>fs[]>>
    fs[])

val asm_fetch_aux_eq2 = prove(
``asm_fetch_aux (adjust_pc pc code) (filter_skip code) = x ⇒
  ∃k.
  asm_fetch_aux (pc+k) code = x ∧
  all_skips pc code k``,
  metis_tac[asm_fetch_aux_eq])

val all_skips_evaluate_0 = all_skips_evaluate |>SIMP_RULE std_ss [PULL_FORALL]|>(Q.SPECL[`k`,`s`,`0`])|>GEN_ALL|>SIMP_RULE std_ss[]

val all_skips_evaluate_rw = prove(``
  all_skips s.pc s.code k ∧ ¬s.failed ∧
  s.clock = clk + k ∧
  t = s with <| pc:= s.pc +k ; clock := clk |> ⇒
  evaluate s = evaluate t``,
  rw[]>>
  qabbrev_tac`s' = s with clock := clk`>>
  `s = s' with clock := s'.clock +k` by
    fs[Abbr`s'`,state_component_equality]>>
  `s' with pc := s.pc +k =
   s' with <| pc := s'.pc +k ; clock := s'.clock|>` by fs[state_component_equality]>>
   ntac 2 (pop_assum SUBST_ALL_TAC)>>
   match_mp_tac all_skips_evaluate_0>>
   fs[state_component_equality])

(*For all initial code there is some all_skips*)
val all_skips_initial_adjust = prove(``
  ∀code.
  ∃k. all_skips 0 code k ∧ adjust_pc k code = 0``,
  Induct>>fs[all_skips_def]
  >-
    (qexists_tac`0`>>fs[adjust_pc_def,asm_fetch_aux_def])
  >>
  Induct>>Induct_on`l`>>rw[]
  >-
    (simp[Once adjust_pc_def]>>
    qexists_tac`k`>>fs[asm_fetch_aux_def])
  >>
    pop_assum(qspec_then`n` assume_tac)>>fs[]>>
    Cases_on`h`>>
    simp[Once adjust_pc_def,asm_fetch_aux_def,is_Label_def,not_skip_def]
    >-
      (qexists_tac`k'`>>fs[])
    >-
      (Cases_on`a=Inst Skip`>>fs[]
      >-
        (qexists_tac`k'+1`>>rw[]>>
        `i-1 < k'` by DECIDE_TAC>>
        metis_tac[])
      >> (qexists_tac`0`>>fs[]))
    >> (qexists_tac`0`>>fs[]))

(*May need strengthening*)
val loc_to_pc_eq_NONE = prove(``
  ∀n1 n2 code.
  loc_to_pc n1 n2 (filter_skip code) = NONE ⇒
  loc_to_pc n1 n2 code = NONE``,
  ho_match_mp_tac loc_to_pc_ind>>rw[]>>
  fs[filter_skip_def]>>
  fs[Once loc_to_pc_def]>>IF_CASES_TAC>>fs[]>>
  FULL_CASE_TAC>>fs[]>>rfs[]>>
  IF_CASES_TAC>>
  fs[]>>
  TRY
    (qpat_assum`A=NONE` mp_tac>>
    IF_CASES_TAC>>fs[]>>
    simp[Once loc_to_pc_def]>>
    EVERY_CASE_TAC>>fs[]>>NO_TAC)>>
  fs[not_skip_def])

val loc_to_pc_eq_SOME = prove(``
  ∀n1 n2 code pc.
  loc_to_pc n1 n2 (filter_skip code) = SOME pc ⇒
  ∃pc' k.
  loc_to_pc n1 n2 code = SOME pc' ∧
  all_skips pc' code k ∧
  adjust_pc (pc'+k) code = pc``,
  ho_match_mp_tac loc_to_pc_ind>>rw[]
  >-
    (fs[filter_skip_def,adjust_pc_def]>>
    qexists_tac`0`>>fs[all_skips_def,asm_fetch_aux_def]>>
    IF_CASES_TAC>>fs[])
  >>
  fs[Once loc_to_pc_def]>>IF_CASES_TAC>>fs[]
  >-
    (fs[filter_skip_def,Once loc_to_pc_def]>>
    qpat_assum`A=pc` sym_sub_tac>>
    fs[all_skips_initial_adjust])
  >>
    (FULL_CASE_TAC>>fs[filter_skip_def,Once loc_to_pc_def]>>rfs[]
    >-
      (qexists_tac`k'`>>
      simp[Once adjust_pc_def]>>fs[all_skips_def,asm_fetch_aux_def]>>
      IF_CASES_TAC>>fs[]>>fs[Once adjust_pc_def])
    >>
    IF_CASES_TAC>>fs[]
    >-
      (fs[not_skip_def]>>
      qpat_assum`A=pc` sym_sub_tac>>
      fs[all_skips_initial_adjust])
    >>
      (Cases_on`not_skip h`>>fs[]
      >-
        (qpat_assum`A=SOME pc` mp_tac>>
        simp[Once loc_to_pc_def]>>
        rw[]>>last_x_assum(qspec_then`pc-1` mp_tac)>>
        discharge_hyps>- (EVERY_CASE_TAC>>fs[]>>DECIDE_TAC)>>
        rw[]>>
        `pc ≠ 0` by
          (EVERY_CASE_TAC>>fs[]>>
          TRY(DECIDE_TAC)>>
          Cases_on`pc`>>fs[])>>
        simp[Once adjust_pc_def]>>
        Cases_on`is_Label h`>>fs[]
        >-
          (*I think loc_to_pc is incorrect*)
          cheat
        >>
          qexists_tac`k'`>>fs[all_skips_def,asm_fetch_aux_def]>>
          `!x. pc''+1 +x -1 = pc''+x` by DECIDE_TAC>>
          fs[arithmeticTheory.ADD_COMM]>>
          DECIDE_TAC)
      >>
        last_x_assum(qspec_then`pc` assume_tac)>>rfs[]>>
        Cases_on`h`>>fs[not_skip_def,is_Label_def]>>
        Cases_on`a`>>TRY(Cases_on`i`) >>
        simp[Once adjust_pc_def]>>
        fs[all_skips_def,asm_fetch_aux_def,is_Label_def,not_skip_def]>>
        qexists_tac`k'`>>fs[arithmeticTheory.ADD_COMM]>>
        `!x. x + (pc''+1) -1 = x + pc''` by DECIDE_TAC>>
        fs[])))

val same_inst_tac = fs[asm_fetch_def,state_rel_def,state_component_equality]>>
    rfs[]>>
    imp_res_tac asm_fetch_aux_eq2>>
    imp_res_tac all_skips_evaluate_0>>
    rw[]>>qexists_tac`k`>>fs[]>>
    rfs[DECIDE``A+B = B+A:num``]>>
    simp[Once evaluate_def,asm_fetch_def];

val filter_correct = prove(
  ``!(s1:('a,'ffi) labSem$state) t1 res s2.
      (evaluate s1 = (res,s2)) /\ state_rel s1 t1 /\ ~t1.failed ==>
      ?k t2.
        (evaluate (t1 with clock := s1.clock + k) = (res,t2)) /\
        (s2.ffi = t2.ffi)``,
  ho_match_mp_tac evaluate_ind>>rw[]>>
  qpat_assum`evaluate s1 = A` mp_tac>>
  simp[Once evaluate_def]>>
  IF_CASES_TAC>-
    (simp[Once evaluate_def]>>
    strip_tac>>
    qexists_tac`0`>>
    qexists_tac`t1 with clock:=0`>>
    fs[state_rel_def])>>
  Cases_on`asm_fetch s1`>>fs[]>- same_inst_tac>>
  Cases_on`x`>>fs[] >- same_inst_tac
  >-
    (Cases_on`a`>>fs[]>>TRY(same_inst_tac>>NO_TAC)>>
    fs[asm_fetch_def,state_rel_def]>>rfs[]>>
    imp_res_tac asm_fetch_aux_eq2>>
    imp_res_tac all_skips_evaluate>>
    pop_assum mp_tac>>simp[Once evaluate_def,SimpRHS,asm_fetch_def]>>
    fs[DECIDE``A+B=B+A:num``]
    >-
      (Cases_on`i`>>fs[asm_inst_def,upd_reg_def,arith_upd_def,mem_op_def]
      >-
        (fs[all_skips_def]>>
        metis_tac[arithmeticTheory.ADD_COMM])
      >-
        (fs[inc_pc_def,dec_clock_def]>>
        rw[]>>res_tac>>
        ntac 2 (pop_assum kall_tac)>>
        first_assum(qspec_then`0` assume_tac)>>fs[]>>
        qmatch_assum_abbrev_tac`evaluate A = evaluate B`>>
        first_x_assum(qspec_then`B` mp_tac)>>
        discharge_hyps>-
         (simp[inc_pc_def,dec_clock_def,Abbr`B`,state_component_equality]>>
         `k + (t1.pc +1) = (t1.pc + k + 1)` by DECIDE_TAC>>fs[]>>
         metis_tac[adjust_pc_all_skips])>>
        rw[Abbr`B`]>>
        qexists_tac`k+k'`>>qexists_tac`t2`>>fs[]>>
        qpat_assum`Z=(res,t2)` sym_sub_tac>>
        first_x_assum(qspec_then`k'` assume_tac)>>
        `∀x.x + t1.clock -1 = x + (t1.clock -1)` by DECIDE_TAC>>rfs[]>>
        metis_tac[arithmeticTheory.ADD_COMM,arithmeticTheory.ADD_ASSOC])
      >>
        (*Should be similar to the previous case but tedious*)
        cheat)
    >>
      (*upd_pc induction*)
      cheat)
  >>
    Cases_on`a`>>
    fs[asm_fetch_def,state_rel_def]>>rfs[]>>
    imp_res_tac asm_fetch_aux_eq2>>
    imp_res_tac all_skips_evaluate>>
    pop_assum mp_tac>>simp[Once evaluate_def,SimpRHS,asm_fetch_def]>>
    fs[DECIDE``A+B=B+A:num``]
    >-
      (*TODO: Factor out the "induction part" into a tactic*)
      (fs[get_pc_value_def]>>Cases_on`l'`>>fs[]>>
      Cases_on`loc_to_pc n' n0 (filter_skip t1.code)`>>fs[]
      >-
        (imp_res_tac loc_to_pc_eq_NONE>>fs[]>>
        same_inst_tac>>fs[get_pc_value_def])
      >>
        imp_res_tac loc_to_pc_eq_SOME>>fs[]>>
        fs[get_pc_value_def,upd_pc_def,dec_clock_def]>>
        rw[]>>
        first_assum(qspec_then`k'` assume_tac)>>fs[]>>
        qmatch_assum_abbrev_tac`evaluate A = evaluate B`>>
        res_tac>>ntac 1 (pop_assum kall_tac)>>
        first_x_assum(qspec_then`B with <|pc := pc'+k'; clock:=t1.clock-1|>` mp_tac)>>
        discharge_hyps>-
         (simp[inc_pc_def,dec_clock_def,Abbr`B`,state_component_equality])>>
        rw[Abbr`B`]>>
        qexists_tac`k+k'+k''`>>qexists_tac`t2`>>fs[]>>
        first_x_assum(qspec_then`k'+k''` assume_tac)>>
        qmatch_assum_abbrev_tac`evaluate B = evaluate C`>>
        qmatch_assum_abbrev_tac`evaluate D = (res,t2)`>>
        `evaluate C = evaluate D` by
          (match_mp_tac (GEN_ALL all_skips_evaluate_rw)>>
          unabbrev_all_tac>>fs[state_component_equality]>>
          DECIDE_TAC)>>
        metis_tac[arithmeticTheory.ADD_COMM,arithmeticTheory.ADD_ASSOC])
    >-
      (*updpc*)
      cheat
    >-
      (*updpc*)
      cheat
    >-
      (fs[inc_pc_def,dec_clock_def,upd_reg_def]>>
       rw[]>>res_tac>>
       ntac 2 (pop_assum kall_tac)>>
       first_assum(qspec_then`0` assume_tac)>>fs[]>>
       qmatch_assum_abbrev_tac`evaluate A = evaluate B`>>
       first_x_assum(qspec_then`B` mp_tac)>>
       discharge_hyps>-
         (simp[inc_pc_def,dec_clock_def,Abbr`B`,state_component_equality]>>
         `k + (t1.pc +1) = (t1.pc + k + 1)` by DECIDE_TAC>>fs[]>>
         metis_tac[adjust_pc_all_skips])>>
       rw[Abbr`B`]>>
       qexists_tac`k+k'`>>qexists_tac`t2`>>fs[]>>
       qpat_assum`Z=(res,t2)` sym_sub_tac>>
       first_x_assum(qspec_then`k'` assume_tac)>>
       `∀x.x + t1.clock -1 = x + (t1.clock -1)` by DECIDE_TAC>>rfs[]>>
       metis_tac[arithmeticTheory.ADD_COMM,arithmeticTheory.ADD_ASSOC])
    >-
      (reverse(Cases_on`t1.regs t1.len_reg`>>fs[])>-same_inst_tac>>
      (Cases_on`t1.regs t1.link_reg`>>fs[])>-same_inst_tac>>
      reverse(Cases_on`t1.regs t1.ptr_reg`>>fs[])>-same_inst_tac>>
      Cases_on`read_bytearray c'' (w2n c') t1.mem t1.mem_domain t1.be`>>fs[]
      >- same_inst_tac>>
      Cases_on`loc_to_pc n'' n0 (filter_skip t1.code)`>>fs[]
      >-
        (imp_res_tac loc_to_pc_eq_NONE>>fs[]>>
        same_inst_tac)
      >>
        imp_res_tac loc_to_pc_eq_SOME>>fs[]>>
        split_pair_tac>>fs[]>>
        rw[]>>
        first_assum(qspec_then`k'` assume_tac)>>fs[]>>
        qmatch_assum_abbrev_tac`evaluate A = evaluate B`>>
        res_tac>>ntac 1 (pop_assum kall_tac)>>
        first_x_assum(qspec_then`B with <|pc := pc'+k'; clock:=t1.clock-1|>` mp_tac)>>
        discharge_hyps>-
         (simp[inc_pc_def,dec_clock_def,Abbr`B`,state_component_equality])>>
        rw[Abbr`B`]>>
        qexists_tac`k+k'+k''`>>qexists_tac`t2`>>fs[]>>
        first_x_assum(qspec_then`k'+k''` assume_tac)>>
        qmatch_assum_abbrev_tac`evaluate B = evaluate C`>>
        qmatch_assum_abbrev_tac`evaluate D = (res,t2)`>>
        `evaluate C = evaluate D` by
          (match_mp_tac (GEN_ALL all_skips_evaluate_rw)>>
          unabbrev_all_tac>>fs[state_component_equality]>>
          DECIDE_TAC)>>
        metis_tac[arithmeticTheory.ADD_COMM,arithmeticTheory.ADD_ASSOC])
    >-
      same_inst_tac
    >>
      EVERY_CASE_TAC>>fs[]>>rw[]>>
      same_inst_tac)

(*Broken*)
val state_rel_IMP_sem_EQ_sem = prove(
  ``!s t. state_rel s t ==> semantics s = semantics t``,
  rw[] >> simp[FUN_EQ_THM]
  \\ reverse Cases
  \\ fs [labSemTheory.semantics_def]
  \\ rpt strip_tac
  THEN1 (* Fail *)
   (eq_tac \\ rpt strip_tac THEN1
     (Cases_on `evaluate (s with clock := k)`
      \\ fs [] \\ rw []
      \\ `state_rel (s with clock := k) (t with clock := k)` by
            (fs [state_rel_def,state_component_equality])
      \\ imp_res_tac filter_correct \\ fs [] \\ rfs[]
      \\ Q.LIST_EXISTS_TAC [`k+k'`] \\ fs [])
    \\ Cases_on `evaluate (t with clock := k)`
    \\ fs [] \\ rw [] \\ CCONTR_TAC \\ fs []
    \\ pop_assum (mp_tac o Q.SPECL [`k`]) \\ rpt strip_tac
    \\ Cases_on `evaluate (s with clock := k)`
    \\ fs []
    \\ `state_rel (s with clock := k) (t with clock := k)` by
          (fs [state_rel_def,state_component_equality])
    \\ imp_res_tac filter_correct \\ fs [] \\ rfs[]
    \\ imp_res_tac evaluate_ADD_clock \\ fs [])
  THEN1 (* Terminate *)
   (eq_tac \\ rpt strip_tac
    THEN1
     (`state_rel (s with clock := k) (t with clock := k)` by
            (fs [state_rel_def,state_component_equality])
      \\ imp_res_tac filter_correct \\ fs [] \\ rw [] \\ fs []
      \\ Q.LIST_EXISTS_TAC [`k+k'`] \\ fs [])
    \\ CCONTR_TAC \\ fs []
    \\ pop_assum (mp_tac o Q.SPECL [`k`]) \\ rpt strip_tac
    \\ `state_rel (s with <| clock := k|>) (t with <| clock := k|>)` by
            (fs [state_rel_def,state_component_equality])
    \\ fs [] \\ imp_res_tac filter_correct \\ fs [] \\ rfs[]
    \\ Cases_on `evaluate (s with clock := k)` \\ fs []
    \\ imp_res_tac evaluate_ADD_clock \\ fs []
    \\ Cases_on `o'` \\ fs [] \\ rw [] \\ fs []
    \\ cheat)
  THEN1 (* Diverge *) cheat);

val filter_skip_semantics = store_thm("filter_skip_semantics",
  ``!s. (s.pc = 0) ==>
        semantics (s with code := filter_skip s.code) = semantics s``,
  rpt strip_tac \\ match_mp_tac state_rel_IMP_sem_EQ_sem
  \\ fs [state_rel_def,state_component_equality,Once adjust_pc_def]);

val _ = export_theory();
