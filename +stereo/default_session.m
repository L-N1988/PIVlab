function session = default_session()
%DEFAULT_SESSION Create the default Stereo-PIV session container.

session = struct();
session.schema_version = 1;
session.status = 'initialized';
session.settings = stereo.default_settings();

session.inputs = struct();
session.inputs.view1_files = {};
session.inputs.view2_files = {};
session.inputs.pairs = struct('index', {}, 'view1', {}, 'view2', {});

session.gui = struct();
session.gui.active_view = 1;
session.gui.pair_count = 0;
session.gui.views = cell(1,2);

session.calibration = struct();
session.calibration.mono = cell(1, 2);
session.calibration.stereo = [];
session.calibration.mapping = [];

session.twod = struct();
session.twod.piv_settings = [];
session.twod.preproc_settings = [];
session.twod.view1 = [];
session.twod.view2 = [];

session.disparity = struct();
session.disparity.status = 'not_run';
session.disparity.model = [];
session.disparity.history = {};

session.results = struct();
session.results.status = 'not_run';
session.results.x = [];
session.results.y = [];
session.results.u = [];
session.results.v = [];
session.results.w = [];
session.results.quality = [];

session.notes = {'TODO: populate with stereo workflow state.'};
end
