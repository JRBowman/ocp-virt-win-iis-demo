# Setup for this Demo:
1. Download the `Windows Server 2022 Evaluation ISO` from Microsoft (link to be added)
2. Upload the `Windows Server 2022 ISO` to OpenShift using the PVC upload form in the console -or- using `virtctl`
3. Add the primary YAML to a cluster that has `OpenShift Virtualization` & `OpenShift Pipelines` installed
4. Track progress of Windows Server install - in some cases, you may need to go the Virtual Machine -> Console and "Press Any Key..." to start the Windows Server Installation process
5. Once the Windows Server instance is installed and running, it should be hosting the .NET API in IIS on `port 80`, Services and Routes for these resources are automatically created by the YAML in this repo
6. Track progress of the pipeline running the build and deployment of the container-based User Interface that links up with the API on the Windows Server
7. Once the UI is built and deployed, accessing it should show the Status of the API Connection on the home screen.
8. At this point, everything should be installed and configured for demonstration! The UI is an `Angular 15 Application` and the backend service is a `.NET ASP.NET WebAPI`

`TODO: add more detailed instructions, links to Windows Server Evaluation ISO, and Finish the SysPrep file to automatically install the IIS Server Role`