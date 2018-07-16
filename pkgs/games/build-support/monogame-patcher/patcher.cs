using System.Collections.Generic;
using System.IO;
using System.Linq;
using System;

using Mono.Cecil.Cil;
using Mono.Cecil.Rocks;
using Mono.Cecil;

using CommandLine;

class GenericOptions
{
    [Option('i', "infile", Required=true, HelpText="Input file to transform.")]
    public string inputFile { get; set; }
    [Option('o', "outfile", HelpText="File to write transformed data to.")]
    public string outputFile { get; set; }
}

class Command {
    protected string infile;
    protected string outfile;
    protected ModuleDefinition module;

    public Command(GenericOptions options) {
        if (options.outputFile == null)
            this.outfile = options.inputFile;
        else
            this.outfile = options.outputFile;
        this.infile = options.inputFile;

        var rp = new ReaderParameters {
            ReadWrite = this.infile == this.outfile
        };
        this.module = ModuleDefinition.ReadModule(this.infile, rp);
    }

    public void save() {
        if (this.outfile == this.infile)
            this.module.Write();
        else
            this.module.Write(this.outfile);
    }
}

[Verb("fix-filestreams", HelpText="Fix System.IO.FileStream constructors"
                                 +" to open files read-only.")]
class FixFileStreamsCmd : GenericOptions {
    [Value(0, Required=true, MetaName = "type", HelpText = "Types to patch.")]
    public IEnumerable<string> typesToPatch { get; set; }
};

class FixFileStreams : Command {
    public FixFileStreams(FixFileStreamsCmd options) : base(options) {
        var filtered = this.module.Types
            .Where(p => options.typesToPatch.Contains(p.Name));

        foreach (var toPatch in filtered)
            patch_type(toPatch);

        this.save();
    }

    private void patch_method(MethodDefinition md) {
        var il = md.Body.GetILProcessor();

        var fileStreams = md.Body.Instructions
            .Where(i => i.OpCode == OpCodes.Newobj)
            .Where(i => (i.Operand as MethodReference).DeclaringType
                    .FullName == "System.IO.FileStream");

        foreach (Instruction i in fileStreams.ToList()) {
            var fileAccessRead = il.Create(OpCodes.Ldc_I4_1);
            il.InsertBefore(i, fileAccessRead);

            var ctorType = this.module.AssemblyReferences.Select(
                x => new {
                    type = this.module.AssemblyResolver.Resolve(x)
                        .MainModule.GetType("System.IO.FileStream")
                }
            ).Where(x => x.type != null).Select(x => x.type).First();

            string wantedCtor = "System.Void System.IO.FileStream"
                              + "::.ctor(System.String,"
                              + "System.IO.FileMode,"
                              + "System.IO.FileAccess)";

            var newCtor = ctorType.GetConstructors()
                .Single(x => x.ToString() == wantedCtor);

            var refCtor = this.module.ImportReference(newCtor);
            il.Replace(i, il.Create(OpCodes.Newobj, refCtor));
        }
    }

    private void patch_type(TypeDefinition td) {
        foreach (var nested in td.NestedTypes) patch_type(nested);
        foreach (MethodDefinition md in td.Methods) patch_method(md);
    }
}

public class patcher {

    public static int Main(string[] args) {
        Parser.Default.ParseArguments<GenericOptions, FixFileStreamsCmd>(args)
            .WithParsed<FixFileStreamsCmd>(opts => new FixFileStreams(opts));
        return 0;
    }
}
