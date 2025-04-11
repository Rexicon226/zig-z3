const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const src = b.dependency("z3", .{});

    const z3 = b.addLibrary(.{
        .name = "z3",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(z3);
    z3.linkLibCpp();
    z3.addIncludePath(src.path("src"));
    z3.addIncludePath(b.path("generated"));

    z3.addCSourceFiles(.{
        .root = src.path("src"),
        .files = z3_source_files,
        .flags = &.{
            // TODO: package libgmp for build.zig as well!
            "-D_MP_INTERNAL",
            switch (optimize) {
                .Debug => "-DZ3DEBUG",
                else => "",
            },
        },
    });
    z3.addCSourceFiles(.{
        .root = b.path("generated/api"),
        .files = &.{
            "api_log_macros.cpp",
            "api_commands.cpp",
        },
    });
    z3.addCSourceFiles(.{
        .root = b.path("generated"),
        .files = &.{
            "mem_initializer.cpp",
            "install_tactic.cpp",
            "gparams_register_modules.cpp",
        },
        .flags = &.{
            "-D_MP_INTERNAL",
            switch (optimize) {
                .Debug => "-DZ3DEBUG",
                else => "",
            },
        },
    });

    const z3_version = b.addConfigHeader(.{
        .style = .{ .cmake = src.path("src/util/z3_version.h.in") },
        .include_path = "util/z3_version.h",
    }, .{
        .Z3_VERSION_MAJOR = 4,
        .Z3_VERSION_MINOR = 14,
        .Z3_VERSION_PATCH = 0,
        .Z3_VERSION_TWEAK = 0,
        .Z3_FULL_VERSION = "\"4.14.0\"",
    });
    z3.addConfigHeader(z3_version);

    const translate_c = b.addTranslateC(.{
        .root_source_file = src.path("src/api/z3.h"),
        .target = target,
        .optimize = optimize,
    });
    translate_c.addIncludePath(src.path("src/api"));

    const z3_mod = b.addModule("z3", .{
        .root_source_file = translate_c.getOutput(),
        .target = target,
        .optimize = optimize,
    });
    z3_mod.linkLibrary(z3);

    const z3_bindings = b.addModule("z3_bindings", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    z3_bindings.addImport("z3", z3_mod);

    const example = b.addExecutable(.{
        .root_source_file = b.path("example.zig"),
        .name = "example",
        .target = target,
        .optimize = optimize,
    });
    example.root_module.addImport("z3", z3_bindings);

    const run_example = b.step("example", "Runs the example");
    run_example.dependOn(&b.addRunArtifact(example).step);
}

const z3_source_files: []const []const u8 = &.{
    "ackermannization/ackermannize_bv_model_converter.cpp",
    "ackermannization/ackermannize_bv_tactic.cpp",
    "ackermannization/ackr_bound_probe.cpp",
    "ackermannization/ackr_helper.cpp",
    "ackermannization/ackr_model_converter.cpp",
    "ackermannization/lackr_model_constructor.cpp",
    "ackermannization/lackr_model_converter_lazy.cpp",
    "ackermannization/lackr.cpp",
    "api/api_algebraic.cpp",
    "api/api_arith.cpp",
    "api/api_array.cpp",
    "api/api_ast_map.cpp",
    "api/api_ast_vector.cpp",
    "api/api_ast.cpp",
    "api/api_bv.cpp",
    "api/api_config_params.cpp",
    "api/api_context.cpp",
    "api/api_datalog.cpp",
    "api/api_datatype.cpp",
    "api/api_fpa.cpp",
    "api/api_goal.cpp",
    "api/api_log.cpp",
    "api/api_model.cpp",
    "api/api_numeral.cpp",
    "api/api_opt.cpp",
    "api/api_params.cpp",
    "api/api_parsers.cpp",
    "api/api_pb.cpp",
    "api/api_polynomial.cpp",
    "api/api_qe.cpp",
    "api/api_quant.cpp",
    "api/api_rcf.cpp",
    "api/api_seq.cpp",
    "api/api_solver.cpp",
    "api/api_special_relations.cpp",
    "api/api_stats.cpp",
    "api/api_tactic.cpp",
    "api/z3_replayer.cpp",
    "ast/act_cache.cpp",
    "ast/arith_decl_plugin.cpp",
    "ast/array_decl_plugin.cpp",
    "ast/array_peq.cpp",
    "ast/ast_ll_pp.cpp",
    "ast/ast_lt.cpp",
    "ast/ast_pp_dot.cpp",
    "ast/ast_pp_util.cpp",
    "ast/ast_printer.cpp",
    "ast/ast_smt_pp.cpp",
    "ast/ast_smt2_pp.cpp",
    "ast/ast_translation.cpp",
    "ast/ast_util.cpp",
    "ast/ast.cpp",
    "ast/bv_decl_plugin.cpp",
    "ast/char_decl_plugin.cpp",
    "ast/converters/equiv_proof_converter.cpp",
    "ast/converters/expr_inverter.cpp",
    "ast/converters/generic_model_converter.cpp",
    "ast/converters/horn_subsume_model_converter.cpp",
    "ast/converters/model_converter.cpp",
    "ast/converters/proof_converter.cpp",
    "ast/converters/replace_proof_converter.cpp",
    "ast/cost_evaluator.cpp",
    "ast/datatype_decl_plugin.cpp",
    "ast/decl_collector.cpp",
    "ast/display_dimacs.cpp",
    "ast/dl_decl_plugin.cpp",
    "ast/euf/euf_ac_plugin.cpp",
    "ast/euf/euf_arith_plugin.cpp",
    "ast/euf/euf_bv_plugin.cpp",
    "ast/euf/euf_egraph.cpp",
    "ast/euf/euf_enode.cpp",
    "ast/euf/euf_etable.cpp",
    "ast/euf/euf_justification.cpp",
    "ast/euf/euf_plugin.cpp",
    "ast/euf/euf_specrel_plugin.cpp",
    "ast/expr_abstract.cpp",
    "ast/expr_functors.cpp",
    "ast/expr_map.cpp",
    "ast/expr_stat.cpp",
    "ast/expr_substitution.cpp",
    "ast/expr2polynomial.cpp",
    "ast/expr2var.cpp",
    "ast/for_each_ast.cpp",
    "ast/for_each_expr.cpp",
    "ast/format.cpp",
    "ast/fpa_decl_plugin.cpp",
    "ast/fpa/bv2fpa_converter.cpp",
    "ast/fpa/fpa2bv_converter.cpp",
    "ast/fpa/fpa2bv_rewriter.cpp",
    "ast/func_decl_dependencies.cpp",
    "ast/has_free_vars.cpp",
    "ast/macro_substitution.cpp",
    "ast/macros/macro_finder.cpp",
    "ast/macros/macro_manager.cpp",
    "ast/macros/macro_util.cpp",
    "ast/macros/quantifier_macro_info.cpp",
    "ast/macros/quasi_macros.cpp",
    "ast/normal_forms/defined_names.cpp",
    "ast/normal_forms/elim_term_ite.cpp",
    "ast/normal_forms/name_exprs.cpp",
    "ast/normal_forms/nnf.cpp",
    "ast/normal_forms/pull_quant.cpp",
    "ast/num_occurs.cpp",
    "ast/occurs.cpp",
    "ast/pattern/expr_pattern_match.cpp",
    "ast/pattern/pattern_inference.cpp",
    "ast/pb_decl_plugin.cpp",
    "ast/polymorphism_inst.cpp",
    "ast/polymorphism_util.cpp",
    "ast/pp.cpp",
    "ast/proofs/proof_checker.cpp",
    "ast/proofs/proof_utils.cpp",
    "ast/quantifier_stat.cpp",
    "ast/recfun_decl_plugin.cpp",
    "ast/reg_decl_plugins.cpp",
    "ast/rewriter/arith_rewriter.cpp",
    "ast/rewriter/array_rewriter.cpp",
    "ast/rewriter/ast_counter.cpp",
    "ast/rewriter/bit_blaster/bit_blaster_rewriter.cpp",
    "ast/rewriter/bit_blaster/bit_blaster.cpp",
    "ast/rewriter/bit2int.cpp",
    "ast/rewriter/bool_rewriter.cpp",
    "ast/rewriter/bv_bounds.cpp",
    "ast/rewriter/bv_elim.cpp",
    "ast/rewriter/bv_rewriter.cpp",
    "ast/rewriter/bv2int_translator.cpp",
    "ast/rewriter/cached_var_subst.cpp",
    "ast/rewriter/char_rewriter.cpp",
    "ast/rewriter/datatype_rewriter.cpp",
    "ast/rewriter/der.cpp",
    "ast/rewriter/distribute_forall.cpp",
    "ast/rewriter/dl_rewriter.cpp",
    "ast/rewriter/dom_simplifier.cpp",
    "ast/rewriter/elim_bounds.cpp",
    "ast/rewriter/enum2bv_rewriter.cpp",
    "ast/rewriter/expr_replacer.cpp",
    "ast/rewriter/expr_safe_replace.cpp",
    "ast/rewriter/factor_equivs.cpp",
    "ast/rewriter/factor_rewriter.cpp",
    "ast/rewriter/fpa_rewriter.cpp",
    "ast/rewriter/func_decl_replace.cpp",
    "ast/rewriter/inj_axiom.cpp",
    "ast/rewriter/label_rewriter.cpp",
    "ast/rewriter/macro_replacer.cpp",
    "ast/rewriter/maximize_ac_sharing.cpp",
    "ast/rewriter/mk_extract_proc.cpp",
    "ast/rewriter/mk_simplified_app.cpp",
    "ast/rewriter/pb_rewriter.cpp",
    "ast/rewriter/pb2bv_rewriter.cpp",
    "ast/rewriter/push_app_ite.cpp",
    "ast/rewriter/quant_hoist.cpp",
    "ast/rewriter/recfun_rewriter.cpp",
    "ast/rewriter/rewriter.cpp",
    "ast/rewriter/seq_axioms.cpp",
    "ast/rewriter/seq_eq_solver.cpp",
    "ast/rewriter/seq_rewriter.cpp",
    "ast/rewriter/seq_skolem.cpp",
    "ast/rewriter/th_rewriter.cpp",
    "ast/rewriter/value_sweep.cpp",
    "ast/rewriter/var_subst.cpp",
    "ast/seq_decl_plugin.cpp",
    "ast/shared_occs.cpp",
    "ast/simplifiers/bit_blaster.cpp",
    "ast/simplifiers/bound_manager.cpp",
    "ast/simplifiers/bound_propagator.cpp",
    "ast/simplifiers/bound_simplifier.cpp",
    "ast/simplifiers/bv_bounds_simplifier.cpp",
    "ast/simplifiers/bv_slice.cpp",
    "ast/simplifiers/card2bv.cpp",
    "ast/simplifiers/demodulator_simplifier.cpp",
    "ast/simplifiers/dependent_expr_state.cpp",
    "ast/simplifiers/distribute_forall.cpp",
    "ast/simplifiers/dominator_simplifier.cpp",
    "ast/simplifiers/elim_unconstrained.cpp",
    "ast/simplifiers/eliminate_predicates.cpp",
    "ast/simplifiers/euf_completion.cpp",
    "ast/simplifiers/extract_eqs.cpp",
    "ast/simplifiers/linear_equation.cpp",
    "ast/simplifiers/max_bv_sharing.cpp",
    "ast/simplifiers/model_reconstruction_trail.cpp",
    "ast/simplifiers/propagate_values.cpp",
    "ast/simplifiers/reduce_args_simplifier.cpp",
    "ast/simplifiers/solve_context_eqs.cpp",
    "ast/simplifiers/solve_eqs.cpp",
    "ast/sls/bvsls_opt_engine.cpp",
    "ast/sls/sat_ddfw.cpp",
    "ast/sls/sls_arith_base.cpp",
    "ast/sls/sls_arith_clausal.cpp",
    "ast/sls/sls_arith_lookahead.cpp",
    "ast/sls/sls_arith_plugin.cpp",
    "ast/sls/sls_array_plugin.cpp",
    "ast/sls/sls_basic_plugin.cpp",
    "ast/sls/sls_bv_engine.cpp",
    "ast/sls/sls_bv_eval.cpp",
    "ast/sls/sls_bv_fixed.cpp",
    "ast/sls/sls_bv_lookahead.cpp",
    "ast/sls/sls_bv_plugin.cpp",
    "ast/sls/sls_bv_terms.cpp",
    "ast/sls/sls_bv_valuation.cpp",
    "ast/sls/sls_context.cpp",
    "ast/sls/sls_datatype_plugin.cpp",
    "ast/sls/sls_euf_plugin.cpp",
    "ast/sls/sls_seq_plugin.cpp",
    "ast/sls/sls_smt_plugin.cpp",
    "ast/sls/sls_smt_solver.cpp",
    "ast/special_relations_decl_plugin.cpp",
    "ast/static_features.cpp",
    "ast/substitution/demodulator_rewriter.cpp",
    "ast/substitution/matcher.cpp",
    "ast/substitution/substitution_tree.cpp",
    "ast/substitution/substitution.cpp",
    "ast/substitution/unifier.cpp",
    "ast/used_vars.cpp",
    "ast/value_generator.cpp",
    "ast/well_sorted.cpp",
    "cmd_context/basic_cmds.cpp",
    "cmd_context/cmd_context_to_goal.cpp",
    "cmd_context/cmd_context.cpp",
    "cmd_context/cmd_util.cpp",
    "cmd_context/echo_tactic.cpp",
    "cmd_context/eval_cmd.cpp",
    "cmd_context/extra_cmds/dbg_cmds.cpp",
    "cmd_context/extra_cmds/polynomial_cmds.cpp",
    "cmd_context/extra_cmds/proof_cmds.cpp",
    "cmd_context/extra_cmds/subpaving_cmds.cpp",
    "cmd_context/parametric_cmd.cpp",
    "cmd_context/pdecl.cpp",
    "cmd_context/simplifier_cmds.cpp",
    "cmd_context/simplify_cmd.cpp",
    "cmd_context/tactic_cmds.cpp",
    "cmd_context/tactic_manager.cpp",
    "math/dd/dd_bdd.cpp",
    "math/dd/dd_fdd.cpp",
    "math/dd/dd_pdd.cpp",
    "math/grobner/grobner.cpp",
    "math/grobner/pdd_simplifier.cpp",
    "math/grobner/pdd_solver.cpp",
    "math/hilbert/hilbert_basis.cpp",
    "math/interval/dep_intervals.cpp",
    "math/interval/interval_mpq.cpp",
    "math/lp/core_solver_pretty_printer.cpp",
    "math/lp/dense_matrix.cpp",
    "math/lp/dioph_eq.cpp",
    "math/lp/emonics.cpp",
    "math/lp/factorization_factory_imp.cpp",
    "math/lp/factorization.cpp",
    "math/lp/gomory.cpp",
    "math/lp/hnf_cutter.cpp",
    "math/lp/horner.cpp",
    "math/lp/indexed_vector.cpp",
    "math/lp/int_branch.cpp",
    "math/lp/int_cube.cpp",
    "math/lp/int_gcd_test.cpp",
    "math/lp/int_solver.cpp",
    "math/lp/lar_core_solver.cpp",
    "math/lp/lar_solver.cpp",
    "math/lp/lp_core_solver_base.cpp",
    "math/lp/lp_primal_core_solver.cpp",
    "math/lp/lp_settings.cpp",
    "math/lp/matrix.cpp",
    "math/lp/mon_eq.cpp",
    "math/lp/monomial_bounds.cpp",
    "math/lp/nex_creator.cpp",
    "math/lp/nla_basics_lemmas.cpp",
    "math/lp/nla_common.cpp",
    "math/lp/nla_core.cpp",
    "math/lp/nla_divisions.cpp",
    "math/lp/nla_grobner.cpp",
    "math/lp/nla_intervals.cpp",
    "math/lp/nla_monotone_lemmas.cpp",
    "math/lp/nla_order_lemmas.cpp",
    "math/lp/nla_powers.cpp",
    "math/lp/nla_solver.cpp",
    "math/lp/nla_tangent_lemmas.cpp",
    "math/lp/nra_solver.cpp",
    "math/lp/permutation_matrix.cpp",
    "math/lp/random_updater.cpp",
    "math/lp/static_matrix.cpp",
    "math/polynomial/algebraic_numbers.cpp",
    "math/polynomial/polynomial_cache.cpp",
    "math/polynomial/polynomial.cpp",
    "math/polynomial/rpolynomial.cpp",
    "math/polynomial/sexpr2upolynomial.cpp",
    "math/polynomial/upolynomial_factorization.cpp",
    "math/polynomial/upolynomial.cpp",
    "math/realclosure/mpz_matrix.cpp",
    "math/realclosure/realclosure.cpp",
    "math/simplex/bit_matrix.cpp",
    "math/simplex/model_based_opt.cpp",
    "math/simplex/simplex.cpp",
    "math/subpaving/subpaving_hwf.cpp",
    "math/subpaving/subpaving_mpf.cpp",
    "math/subpaving/subpaving_mpff.cpp",
    "math/subpaving/subpaving_mpfx.cpp",
    "math/subpaving/subpaving_mpq.cpp",
    "math/subpaving/subpaving.cpp",
    "math/subpaving/tactic/expr2subpaving.cpp",
    "math/subpaving/tactic/subpaving_tactic.cpp",
    "model/array_factory.cpp",
    "model/datatype_factory.cpp",
    "model/func_interp.cpp",
    "model/model_core.cpp",
    "model/model_evaluator.cpp",
    "model/model_implicant.cpp",
    "model/model_macro_solver.cpp",
    "model/model_pp.cpp",
    "model/model_smt2_pp.cpp",
    "model/model_v2_pp.cpp",
    "model/model.cpp",
    "model/model2expr.cpp",
    "model/numeral_factory.cpp",
    "model/struct_factory.cpp",
    "model/value_factory.cpp",
    "muz/base/bind_variables.cpp",
    "muz/base/dl_boogie_proof.cpp",
    "muz/base/dl_context.cpp",
    "muz/base/dl_costs.cpp",
    "muz/base/dl_rule_set.cpp",
    "muz/base/dl_rule_subsumption_index.cpp",
    "muz/base/dl_rule_transformer.cpp",
    "muz/base/dl_rule.cpp",
    "muz/base/dl_util.cpp",
    "muz/base/hnf.cpp",
    "muz/base/rule_properties.cpp",
    "muz/bmc/dl_bmc_engine.cpp",
    "muz/clp/clp_context.cpp",
    "muz/dataflow/dataflow.cpp",
    "muz/ddnf/ddnf.cpp",
    "muz/fp/datalog_parser.cpp",
    "muz/fp/dl_cmds.cpp",
    "muz/fp/dl_register_engine.cpp",
    "muz/fp/horn_tactic.cpp",
    "muz/rel/aig_exporter.cpp",
    "muz/rel/check_relation.cpp",
    "muz/rel/dl_base.cpp",
    "muz/rel/dl_bound_relation.cpp",
    "muz/rel/dl_check_table.cpp",
    "muz/rel/dl_compiler.cpp",
    "muz/rel/dl_external_relation.cpp",
    "muz/rel/dl_finite_product_relation.cpp",
    "muz/rel/dl_instruction.cpp",
    "muz/rel/dl_interval_relation.cpp",
    "muz/rel/dl_lazy_table.cpp",
    "muz/rel/dl_mk_explanations.cpp",
    "muz/rel/dl_mk_similarity_compressor.cpp",
    "muz/rel/dl_mk_simple_joins.cpp",
    "muz/rel/dl_product_relation.cpp",
    "muz/rel/dl_relation_manager.cpp",
    "muz/rel/dl_sieve_relation.cpp",
    "muz/rel/dl_sparse_table.cpp",
    "muz/rel/dl_table_relation.cpp",
    "muz/rel/dl_table.cpp",
    "muz/rel/doc.cpp",
    "muz/rel/karr_relation.cpp",
    "muz/rel/rel_context.cpp",
    "muz/rel/rel_context.cpp",
    "muz/rel/udoc_relation.cpp",
    "muz/spacer/spacer_antiunify.cpp",
    "muz/spacer/spacer_arith_generalizers.cpp",
    "muz/spacer/spacer_arith_kernel.cpp",
    "muz/spacer/spacer_callback.cpp",
    "muz/spacer/spacer_cluster_util.cpp",
    "muz/spacer/spacer_cluster.cpp",
    "muz/spacer/spacer_concretize.cpp",
    "muz/spacer/spacer_conjecture.cpp",
    "muz/spacer/spacer_context.cpp",
    "muz/spacer/spacer_convex_closure.cpp",
    "muz/spacer/spacer_dl_interface.cpp",
    "muz/spacer/spacer_expand_bnd_generalizer.cpp",
    "muz/spacer/spacer_farkas_learner.cpp",
    "muz/spacer/spacer_generalizers.cpp",
    "muz/spacer/spacer_global_generalizer.cpp",
    "muz/spacer/spacer_ind_lemma_generalizer.cpp",
    "muz/spacer/spacer_iuc_proof.cpp",
    "muz/spacer/spacer_iuc_solver.cpp",
    "muz/spacer/spacer_legacy_frames.cpp",
    "muz/spacer/spacer_legacy_mbp.cpp",
    "muz/spacer/spacer_legacy_mev.cpp",
    "muz/spacer/spacer_manager.cpp",
    "muz/spacer/spacer_matrix.cpp",
    "muz/spacer/spacer_mbc.cpp",
    "muz/spacer/spacer_mev_array.cpp",
    "muz/spacer/spacer_pdr.cpp",
    "muz/spacer/spacer_proof_utils.cpp",
    "muz/spacer/spacer_prop_solver.cpp",
    "muz/spacer/spacer_qe_project.cpp",
    "muz/spacer/spacer_quant_generalizer.cpp",
    "muz/spacer/spacer_sat_answer.cpp",
    "muz/spacer/spacer_sem_matcher.cpp",
    "muz/spacer/spacer_sym_mux.cpp",
    "muz/spacer/spacer_unsat_core_learner.cpp",
    "muz/spacer/spacer_unsat_core_plugin.cpp",
    "muz/spacer/spacer_util.cpp",
    "muz/tab/tab_context.cpp",
    "muz/transforms/dl_mk_array_blast.cpp",
    "muz/transforms/dl_mk_array_eq_rewrite.cpp",
    "muz/transforms/dl_mk_array_instantiation.cpp",
    "muz/transforms/dl_mk_backwards.cpp",
    "muz/transforms/dl_mk_bit_blast.cpp",
    "muz/transforms/dl_mk_coalesce.cpp",
    "muz/transforms/dl_mk_coi_filter.cpp",
    "muz/transforms/dl_mk_elim_term_ite.cpp",
    "muz/transforms/dl_mk_filter_rules.cpp",
    "muz/transforms/dl_mk_interp_tail_simplifier.cpp",
    "muz/transforms/dl_mk_karr_invariants.cpp",
    "muz/transforms/dl_mk_loop_counter.cpp",
    "muz/transforms/dl_mk_magic_sets.cpp",
    "muz/transforms/dl_mk_magic_symbolic.cpp",
    "muz/transforms/dl_mk_quantifier_abstraction.cpp",
    "muz/transforms/dl_mk_quantifier_instantiation.cpp",
    "muz/transforms/dl_mk_rule_inliner.cpp",
    "muz/transforms/dl_mk_scale.cpp",
    "muz/transforms/dl_mk_separate_negated_tails.cpp",
    "muz/transforms/dl_mk_slice.cpp",
    "muz/transforms/dl_mk_subsumption_checker.cpp",
    "muz/transforms/dl_mk_synchronize.cpp",
    "muz/transforms/dl_mk_unbound_compressor.cpp",
    "muz/transforms/dl_mk_unfold.cpp",
    "muz/transforms/dl_transforms.cpp",
    "nlsat/nlsat_clause.cpp",
    "nlsat/nlsat_evaluator.cpp",
    "nlsat/nlsat_explain.cpp",
    "nlsat/nlsat_interval_set.cpp",
    "nlsat/nlsat_simple_checker.cpp",
    "nlsat/nlsat_simplify.cpp",
    "nlsat/nlsat_solver.cpp",
    "nlsat/nlsat_types.cpp",
    "nlsat/nlsat_variable_ordering_strategy.cpp",
    "nlsat/tactic/goal2nlsat.cpp",
    "nlsat/tactic/nlsat_tactic.cpp",
    "nlsat/tactic/qfnra_nlsat_tactic.cpp",
    "opt/maxcore.cpp",
    "opt/maxlex.cpp",
    "opt/maxsmt.cpp",
    "opt/opt_cmds.cpp",
    "opt/opt_context.cpp",
    "opt/opt_cores.cpp",
    "opt/opt_lns.cpp",
    "opt/opt_pareto.cpp",
    "opt/opt_parse.cpp",
    "opt/opt_preprocess.cpp",
    "opt/opt_solver.cpp",
    "opt/optsmt.cpp",
    "opt/pb_sls.cpp",
    "opt/sortmax.cpp",
    "opt/totalizer.cpp",
    "opt/wmax.cpp",
    "params/context_params.cpp",
    "params/pattern_inference_params.cpp",
    "parsers/smt2/marshal.cpp",
    "parsers/smt2/smt2parser.cpp",
    "parsers/smt2/smt2scanner.cpp",
    "parsers/util/cost_parser.cpp",
    "parsers/util/pattern_validation.cpp",
    "parsers/util/scanner.cpp",
    "parsers/util/simple_parser.cpp",
    "qe/lite/qe_lite_tactic.cpp",
    "qe/lite/qel.cpp",
    "qe/mbp/mbp_arith.cpp",
    "qe/mbp/mbp_arrays_tg.cpp",
    "qe/mbp/mbp_arrays.cpp",
    "qe/mbp/mbp_basic_tg.cpp",
    "qe/mbp/mbp_datatypes.cpp",
    "qe/mbp/mbp_dt_tg.cpp",
    "qe/mbp/mbp_euf.cpp",
    "qe/mbp/mbp_plugin.cpp",
    "qe/mbp/mbp_qel_util.cpp",
    "qe/mbp/mbp_qel.cpp",
    "qe/mbp/mbp_solve_plugin.cpp",
    "qe/mbp/mbp_term_graph.cpp",
    "qe/nlarith_util.cpp",
    "qe/nlqsat.cpp",
    "qe/qe_arith_plugin.cpp",
    "qe/qe_array_plugin.cpp",
    "qe/qe_bool_plugin.cpp",
    "qe/qe_bv_plugin.cpp",
    "qe/qe_cmd.cpp",
    "qe/qe_datatype_plugin.cpp",
    "qe/qe_dl_plugin.cpp",
    "qe/qe_mbi.cpp",
    "qe/qe_mbp.cpp",
    "qe/qe_tactic.cpp",
    "qe/qe.cpp",
    "qe/qsat.cpp",
    "sat/dimacs.cpp",
    "sat/sat_aig_cuts.cpp",
    "sat/sat_aig_finder.cpp",
    "sat/sat_anf_simplifier.cpp",
    "sat/sat_asymm_branch.cpp",
    "sat/sat_bcd.cpp",
    "sat/sat_big.cpp",
    "sat/sat_clause_set.cpp",
    "sat/sat_clause_use_list.cpp",
    "sat/sat_clause.cpp",
    "sat/sat_cleaner.cpp",
    "sat/sat_config.cpp",
    "sat/sat_cut_simplifier.cpp",
    "sat/sat_cutset.cpp",
    "sat/sat_ddfw_wrapper.cpp",
    "sat/sat_drat.cpp",
    "sat/sat_elim_eqs.cpp",
    "sat/sat_elim_vars.cpp",
    "sat/sat_gc.cpp",
    "sat/sat_integrity_checker.cpp",
    "sat/sat_local_search.cpp",
    "sat/sat_lookahead.cpp",
    "sat/sat_lut_finder.cpp",
    "sat/sat_model_converter.cpp",
    "sat/sat_mus.cpp",
    "sat/sat_npn3_finder.cpp",
    "sat/sat_parallel.cpp",
    "sat/sat_prob.cpp",
    "sat/sat_probing.cpp",
    "sat/sat_proof_trim.cpp",
    "sat/sat_scc.cpp",
    "sat/sat_simplifier.cpp",
    "sat/sat_solver.cpp",
    "sat/sat_solver/inc_sat_solver.cpp",
    "sat/sat_solver/sat_smt_solver.cpp",
    "sat/sat_watched.cpp",
    "sat/sat_xor_finder.cpp",
    "sat/smt/arith_axioms.cpp",
    "sat/smt/arith_diagnostics.cpp",
    "sat/smt/arith_internalize.cpp",
    "sat/smt/arith_solver.cpp",
    "sat/smt/arith_value.cpp",
    "sat/smt/array_axioms.cpp",
    "sat/smt/array_diagnostics.cpp",
    "sat/smt/array_internalize.cpp",
    "sat/smt/array_model.cpp",
    "sat/smt/array_solver.cpp",
    "sat/smt/atom2bool_var.cpp",
    "sat/smt/bv_ackerman.cpp",
    "sat/smt/bv_delay_internalize.cpp",
    "sat/smt/bv_internalize.cpp",
    "sat/smt/bv_invariant.cpp",
    "sat/smt/bv_solver.cpp",
    "sat/smt/bv_theory_checker.cpp",
    "sat/smt/dt_solver.cpp",
    "sat/smt/euf_ackerman.cpp",
    "sat/smt/euf_internalize.cpp",
    "sat/smt/euf_invariant.cpp",
    "sat/smt/euf_model.cpp",
    "sat/smt/euf_proof_checker.cpp",
    "sat/smt/euf_proof.cpp",
    "sat/smt/euf_relevancy.cpp",
    "sat/smt/euf_solver.cpp",
    "sat/smt/fpa_solver.cpp",
    "sat/smt/intblast_solver.cpp",
    "sat/smt/pb_card.cpp",
    "sat/smt/pb_constraint.cpp",
    "sat/smt/pb_internalize.cpp",
    "sat/smt/pb_pb.cpp",
    "sat/smt/pb_solver.cpp",
    "sat/smt/q_clause.cpp",
    "sat/smt/q_ematch.cpp",
    "sat/smt/q_eval.cpp",
    "sat/smt/q_mam.cpp",
    "sat/smt/q_mbi.cpp",
    "sat/smt/q_model_fixer.cpp",
    "sat/smt/q_queue.cpp",
    "sat/smt/q_solver.cpp",
    "sat/smt/q_theory_checker.cpp",
    "sat/smt/recfun_solver.cpp",
    "sat/smt/sat_th.cpp",
    "sat/smt/sls_solver.cpp",
    "sat/smt/specrel_solver.cpp",
    "sat/smt/tseitin_theory_checker.cpp",
    "sat/smt/user_solver.cpp",
    "sat/tactic/goal2sat.cpp",
    "sat/tactic/sat_tactic.cpp",
    "sat/tactic/sat2goal.cpp",
    "smt/arith_eq_adapter.cpp",
    "smt/arith_eq_solver.cpp",
    "smt/dyn_ack.cpp",
    "smt/expr_context_simplifier.cpp",
    "smt/fingerprints.cpp",
    "smt/mam.cpp",
    "smt/old_interval.cpp",
    "smt/params/dyn_ack_params.cpp",
    "smt/params/preprocessor_params.cpp",
    "smt/params/qi_params.cpp",
    "smt/params/smt_params.cpp",
    "smt/params/theory_arith_params.cpp",
    "smt/params/theory_array_params.cpp",
    "smt/params/theory_bv_params.cpp",
    "smt/params/theory_pb_params.cpp",
    "smt/params/theory_seq_params.cpp",
    "smt/params/theory_str_params.cpp",
    "smt/proto_model/proto_model.cpp",
    "smt/qi_queue.cpp",
    "smt/seq_axioms.cpp",
    "smt/seq_eq_solver.cpp",
    "smt/seq_ne_solver.cpp",
    "smt/seq_offset_eq.cpp",
    "smt/seq_regex.cpp",
    "smt/smt_almost_cg_table.cpp",
    "smt/smt_arith_value.cpp",
    "smt/smt_case_split_queue.cpp",
    "smt/smt_cg_table.cpp",
    "smt/smt_checker.cpp",
    "smt/smt_clause_proof.cpp",
    "smt/smt_clause.cpp",
    "smt/smt_conflict_resolution.cpp",
    "smt/smt_consequences.cpp",
    "smt/smt_context_inv.cpp",
    "smt/smt_context_pp.cpp",
    "smt/smt_context_stat.cpp",
    "smt/smt_context.cpp",
    "smt/smt_enode.cpp",
    "smt/smt_farkas_util.cpp",
    "smt/smt_for_each_relevant_expr.cpp",
    "smt/smt_implied_equalities.cpp",
    "smt/smt_internalizer.cpp",
    "smt/smt_justification.cpp",
    "smt/smt_kernel.cpp",
    "smt/smt_literal.cpp",
    "smt/smt_lookahead.cpp",
    "smt/smt_model_checker.cpp",
    "smt/smt_model_finder.cpp",
    "smt/smt_model_generator.cpp",
    "smt/smt_parallel.cpp",
    "smt/smt_quantifier.cpp",
    "smt/smt_quick_checker.cpp",
    "smt/smt_relevancy.cpp",
    "smt/smt_setup.cpp",
    "smt/smt_solver.cpp",
    "smt/smt_statistics.cpp",
    "smt/smt_theory.cpp",
    "smt/smt_value_sort.cpp",
    "smt/smt2_extra_cmds.cpp",
    "smt/tactic/ctx_solver_simplify_tactic.cpp",
    "smt/tactic/smt_tactic_core.cpp",
    "smt/tactic/unit_subsumption_tactic.cpp",
    "smt/theory_arith.cpp",
    "smt/theory_array_bapa.cpp",
    "smt/theory_array_base.cpp",
    "smt/theory_array_full.cpp",
    "smt/theory_array.cpp",
    "smt/theory_bv.cpp",
    "smt/theory_char.cpp",
    "smt/theory_datatype.cpp",
    "smt/theory_dense_diff_logic.cpp",
    "smt/theory_diff_logic.cpp",
    "smt/theory_dl.cpp",
    "smt/theory_dummy.cpp",
    "smt/theory_fpa.cpp",
    "smt/theory_intblast.cpp",
    "smt/theory_lra.cpp",
    "smt/theory_opt.cpp",
    "smt/theory_pb.cpp",
    "smt/theory_recfun.cpp",
    "smt/theory_seq.cpp",
    "smt/theory_sls.cpp",
    "smt/theory_special_relations.cpp",
    "smt/theory_str_mc.cpp",
    "smt/theory_str_regex.cpp",
    "smt/theory_str.cpp",
    "smt/theory_user_propagator.cpp",
    "smt/theory_utvpi.cpp",
    "smt/theory_wmaxsat.cpp",
    "smt/uses_theory.cpp",
    "smt/watch_list.cpp",
    "solver/assertions/asserted_formulas.cpp",
    "solver/check_logic.cpp",
    "solver/check_sat_result.cpp",
    "solver/combined_solver.cpp",
    "solver/mus.cpp",
    "solver/parallel_tactical.cpp",
    "solver/simplifier_solver.cpp",
    "solver/slice_solver.cpp",
    "solver/smt_logics.cpp",
    "solver/solver_na2as.cpp",
    "solver/solver_pool.cpp",
    "solver/solver_preprocess.cpp",
    "solver/solver.cpp",
    "solver/solver2tactic.cpp",
    "solver/tactic2solver.cpp",
    "tactic/aig/aig_tactic.cpp",
    "tactic/aig/aig.cpp",
    "tactic/arith/add_bounds_tactic.cpp",
    "tactic/arith/arith_bounds_tactic.cpp",
    "tactic/arith/bv2int_rewriter.cpp",
    "tactic/arith/bv2real_rewriter.cpp",
    "tactic/arith/degree_shift_tactic.cpp",
    "tactic/arith/diff_neq_tactic.cpp",
    "tactic/arith/eq2bv_tactic.cpp",
    "tactic/arith/factor_tactic.cpp",
    "tactic/arith/fix_dl_var_tactic.cpp",
    "tactic/arith/fm_tactic.cpp",
    "tactic/arith/lia2card_tactic.cpp",
    "tactic/arith/lia2pb_tactic.cpp",
    "tactic/arith/nla2bv_tactic.cpp",
    "tactic/arith/normalize_bounds_tactic.cpp",
    "tactic/arith/pb2bv_model_converter.cpp",
    "tactic/arith/pb2bv_tactic.cpp",
    "tactic/arith/probe_arith.cpp",
    "tactic/arith/purify_arith_tactic.cpp",
    "tactic/arith/recover_01_tactic.cpp",
    "tactic/bv/bit_blaster_model_converter.cpp",
    "tactic/bv/bit_blaster_tactic.cpp",
    "tactic/bv/bv_bound_chk_tactic.cpp",
    "tactic/bv/bv_bounds_tactic.cpp",
    "tactic/bv/bv_size_reduction_tactic.cpp",
    "tactic/bv/bv1_blaster_tactic.cpp",
    "tactic/bv/bvarray2uf_rewriter.cpp",
    "tactic/bv/bvarray2uf_tactic.cpp",
    "tactic/bv/dt2bv_tactic.cpp",
    "tactic/bv/elim_small_bv_tactic.cpp",
    "tactic/core/blast_term_ite_tactic.cpp",
    "tactic/core/cofactor_elim_term_ite.cpp",
    "tactic/core/cofactor_term_ite_tactic.cpp",
    "tactic/core/collect_occs.cpp",
    "tactic/core/collect_statistics_tactic.cpp",
    "tactic/core/ctx_simplify_tactic.cpp",
    "tactic/core/der_tactic.cpp",
    "tactic/core/elim_term_ite_tactic.cpp",
    "tactic/core/elim_uncnstr_tactic.cpp",
    "tactic/core/euf_completion_tactic.cpp",
    "tactic/core/injectivity_tactic.cpp",
    "tactic/core/nnf_tactic.cpp",
    "tactic/core/occf_tactic.cpp",
    "tactic/core/pb_preprocess_tactic.cpp",
    "tactic/core/propagate_values_tactic.cpp",
    "tactic/core/reduce_args_tactic.cpp",
    "tactic/core/simplify_tactic.cpp",
    "tactic/core/special_relations_tactic.cpp",
    "tactic/core/split_clause_tactic.cpp",
    "tactic/core/symmetry_reduce_tactic.cpp",
    "tactic/core/tseitin_cnf_tactic.cpp",
    "tactic/dependency_converter.cpp",
    "tactic/fd_solver/bounded_int2bv_solver.cpp",
    "tactic/fd_solver/enum2bv_solver.cpp",
    "tactic/fd_solver/fd_solver.cpp",
    "tactic/fd_solver/pb2bv_solver.cpp",
    "tactic/fd_solver/smtfd_solver.cpp",
    "tactic/fpa/fpa2bv_model_converter.cpp",
    "tactic/fpa/fpa2bv_tactic.cpp",
    "tactic/fpa/qffp_tactic.cpp",
    "tactic/fpa/qffplra_tactic.cpp",
    "tactic/goal_num_occurs.cpp",
    "tactic/goal_shared_occs.cpp",
    "tactic/goal_util.cpp",
    "tactic/goal.cpp",
    "tactic/portfolio/default_tactic.cpp",
    "tactic/portfolio/smt_strategic_solver.cpp",
    "tactic/portfolio/solver_subsumption_tactic.cpp",
    "tactic/portfolio/solver2lookahead.cpp",
    "tactic/probe.cpp",
    "tactic/sls/sls_tactic.cpp",
    "tactic/smtlogics/nra_tactic.cpp",
    "tactic/smtlogics/qfaufbv_tactic.cpp",
    "tactic/smtlogics/qfauflia_tactic.cpp",
    "tactic/smtlogics/qfbv_tactic.cpp",
    "tactic/smtlogics/qfidl_tactic.cpp",
    "tactic/smtlogics/qflia_tactic.cpp",
    "tactic/smtlogics/qflra_tactic.cpp",
    "tactic/smtlogics/qfnia_tactic.cpp",
    "tactic/smtlogics/qfnra_tactic.cpp",
    "tactic/smtlogics/qfuf_tactic.cpp",
    "tactic/smtlogics/qfufbv_ackr_model_converter.cpp",
    "tactic/smtlogics/qfufbv_tactic.cpp",
    "tactic/smtlogics/quant_tactics.cpp",
    "tactic/smtlogics/smt_tactic.cpp",
    "tactic/tactic.cpp",
    "tactic/tactical.cpp",
    "tactic/ufbv/macro_finder_tactic.cpp",
    "tactic/ufbv/quasi_macros_tactic.cpp",
    "tactic/ufbv/ufbv_rewriter_tactic.cpp",
    "tactic/ufbv/ufbv_tactic.cpp",
    "util/approx_nat.cpp",
    "util/approx_set.cpp",
    "util/bit_util.cpp",
    "util/bit_vector.cpp",
    "util/cmd_context_types.cpp",
    "util/common_msgs.cpp",
    "util/debug.cpp",
    "util/env_params.cpp",
    "util/fixed_bit_vector.cpp",
    "util/gparams.cpp",
    "util/hash.cpp",
    "util/hwf.cpp",
    "util/inf_int_rational.cpp",
    "util/inf_rational.cpp",
    "util/inf_s_integer.cpp",
    "util/lbool.cpp",
    "util/luby.cpp",
    "util/memory_manager.cpp",
    "util/min_cut.cpp",
    "util/mpbq.cpp",
    "util/mpf.cpp",
    "util/mpff.cpp",
    "util/mpfx.cpp",
    "util/mpn.cpp",
    "util/mpq_inf.cpp",
    "util/mpq.cpp",
    "util/mpz.cpp",
    "util/page.cpp",
    "util/params.cpp",
    "util/permutation.cpp",
    "util/prime_generator.cpp",
    "util/rational.cpp",
    "util/region.cpp",
    "util/rlimit.cpp",
    "util/s_integer.cpp",
    "util/scoped_ctrl_c.cpp",
    "util/scoped_timer.cpp",
    "util/sexpr.cpp",
    "util/small_object_allocator.cpp",
    "util/smt2_util.cpp",
    "util/stack.cpp",
    "util/state_graph.cpp",
    "util/statistics.cpp",
    "util/symbol.cpp",
    "util/tbv.cpp",
    "util/timeit.cpp",
    "util/timeout.cpp",
    "util/trace.cpp",
    "util/util.cpp",
    "util/warning.cpp",
    "util/z3_exception.cpp",
    "util/zstring.cpp",
};
