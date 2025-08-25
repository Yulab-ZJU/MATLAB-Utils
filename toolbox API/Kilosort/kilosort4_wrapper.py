import json
import sys
from kilosort import run_kilosort
import numpy as np
import pandas as pd
from pathlib import Path

def main():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "missing settings or opts parameter"}))
        sys.exit(1)

    try:
        settings_path = sys.argv[1]
        opts_path = sys.argv[2]

        with open(settings_path, 'r') as f:
            settings_text = f.read()
            print("Read settings file content:", settings_text)

        with open(opts_path, 'r') as f:
            opts_text = f.read()
            print("Read opts file content:", opts_text)

        settings = json.loads(settings_text)
        opts = json.loads(opts_text)
    except Exception as e:
        print(json.dumps({"error": f"invalid json: {e}"}))
        sys.exit(1)

    try:
        run_kilosort(
            settings=settings,
            probe_name=opts.get('probe_name', None),
            filename=opts.get('filename', None),
            data_dir=opts.get('data_dir', None),
            results_dir=opts.get('results_dir', None),
            data_dtype=opts.get('data_dtype', None),
            do_CAR=opts.get('do_CAR', True),
            invert_sign=opts.get('invert_sign', False),
            device=opts.get('device', None),
            progress_bar=opts.get('progress_bar', None),
            save_extra_vars=opts.get('save_extra_vars', False),
            clear_cache=opts.get('clear_cache', False),
            save_preprocessed_copy=opts.get('save_preprocessed_copy', False),
            bad_channels=opts.get('bad_channels', None),
            shank_idx=opts.get('shank_idx', None),
            verbose_console=opts.get('verbose_console', False),
            verbose_log=opts.get('verbose_log', False)
        )

        # generate cluster_info.tsv
        if opts.get('fs', None) is not None and opts.get('results_dir', None) is not None:
            generate_cluster_info(opts['results_dir'], opts['fs'])
        else:
            print("fs or results_dir not provided, skipping cluster_info.tsv generation.")

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

def generate_cluster_info(results_dir, fs):
    results_dir = Path(results_dir)
    
    spike_clusters = np.load(results_dir / 'spike_clusters.npy')
    spike_times = np.load(results_dir / 'spike_times.npy')
    templates = np.load(results_dir / 'templates.npy')  # shape: n_templates x n_channels x template_length

    unique_clusters = np.unique(spike_clusters)
    cluster_ids, main_channels, n_spikes_list, fr_list, group_list = [], [], [], [], []

    for cid in unique_clusters:
        cluster_ids.append(int(cid))

        idx = np.where(spike_clusters == cid)[0]
        n_spikes = len(idx)
        n_spikes_list.append(n_spikes)

        fr = n_spikes / (spike_times.max() / fs)
        fr_list.append(fr)

        template_idx = int(cid)
        if template_idx >= templates.shape[0]:
            main_ch = -1
        else:
            tmpl = templates[template_idx]
            main_ch = int(np.argmax(np.max(np.abs(tmpl), axis=1)))
        main_channels.append(main_ch)

        group_list.append('unsorted')

    df = pd.DataFrame({
        'cluster_id': cluster_ids,
        'ch': main_channels,
        'n_spikes': n_spikes_list,
        'fr': fr_list,
        'group': group_list
    })
    cluster_info_file = results_dir / 'cluster_info.tsv'
    df.to_csv(cluster_info_file, sep='\t', index=False)
    print(f'cluster_info.tsv saved at {cluster_info_file}')

if __name__ == "__main__":
    main()
