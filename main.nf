fast5dir = params.fast5

Channel
    .fromPath(fast5dir, type: 'dir')
    .map {fast5 ->
        def key = fast5.toString().tokenize('/')[-1]
        return tuple(key,fast5)
    }
   .set { for_basecalling }

outputFastq = 'results/'

process baseCalling {
    cpus 8
    
    input:
    set key, file(fast5) from for_basecalling 
    
    output:
    set file("${key}.*.gz") optional true 

	publishDir outputFastq, pattern: "*.fastq.gz",  mode: 'copy'

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
	    guppy_basecaller ${gpu_cmd} --flowcell ${params.flowcell} --kit ${params.kit} -i ${fast5} --save_path ./${key}_out --cpu_threads_per_caller 1  --num_callers  ${task.cpus} 
        if [ -d ${key}_out/pass/ ]; then
	        cat ${key}_out/pass/*.fastq >> ${key}.fastq
	        gzip ${key}.fastq
        fi
	    ${multi_cmd}
	"""
}
