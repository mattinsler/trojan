module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')
    clean:
      dist: ['dist']
    coffee:
      dist:
        expand: true
        cwd: 'lib'
        src: ['**/*.coffee']
        dest: 'dist'
        ext: '.js'
  
  grunt.loadNpmTasks('grunt-contrib-clean')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  
  grunt.registerTask('default', ['clean', 'coffee'])
