fast5dir = params.fast5

Channel
    .fromPath(fast5dir, type: 'dir')
    .map {fast5 ->
        def key = fast5.toString().tokenize('/')[-1]
        return tuple(key,fast5)
    }
   .set { for_basecalling }


process baseCalling {
    cpus 8
    
    input:
    set key, file(fast5) from for_basecalling 
    
    output:
    file("${key}.*.gz") optional true 

	publishDir "${params.outdir}/${key}", pattern: "*.fastq.gz",  mode: 'copy'
	publishDir "${params.outdir}/${key}", pattern: "sequencing_summary.txt",  mode: 'copy'

    script:
   	def multi_cmd = ""
    def gpu_cmd = ""
    def gpu_prefix = ""
    def infolder = './'
    if (params.GPU == "ON") {
        gpu_prefix = 'export LD_LIBRARY_PATH="/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/.singularity.d/libs"'
       	gpu_cmd = '-x "cuda:0"'
      }
	"""
    ${gpu_prefix}
	    guppy_basecaller ${gpu_cmd} --flowcell ${params.flowcell} --kit ${params.kit} \
            -i ${fast5} --save_path ./${key}_out --cpu_threads_per_caller 1  \
            --num_callers  ${task.cpus} --recursive --gpu_runners_per_device 4 \
            --chunks_per_runner 1024 

        if [ -d ${key}_out/pass/ ]; then
	        cat ${key}_out/pass/*.fastq >> ${key}.PASS.fastq
	        pigz -p8 ${key}.PASS.fastq
        fi

        if [-d ${key}_out/fail/ ]; then
            cat ${key}_out/fail/*.fastq >> ${key}.FAIL.fastq
            pigz -p8 ${key}.FAIL.fastq
        fi

        cp ${key}_out/sequencing_summary.txt .

	    ${multi_cmd}
	"""
}
