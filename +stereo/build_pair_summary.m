function pairs = build_pair_summary(view1_state, view2_state)
%BUILD_PAIR_SUMMARY Build a paired stereo summary from two loaded views.

pair_count = min(view1_state.pair_count, view2_state.pair_count);
if pair_count <= 0
	pairs = struct('index', {}, 'view1_a', {}, 'view1_b', {}, 'view2_a', {}, 'view2_b', {});
	return
end

pairs = repmat(struct('index', 0, 'view1_a', '', 'view1_b', '', 'view2_a', '', 'view2_b', ''), pair_count, 1);
for i = 1:pair_count
	idx = 2*i - 1;
	pairs(i).index = i;
	pairs(i).view1_a = view1_state.filepath{idx};
	pairs(i).view1_b = view1_state.filepath{idx+1};
	pairs(i).view2_a = view2_state.filepath{idx};
	pairs(i).view2_b = view2_state.filepath{idx+1};
end
end
